import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Echte Nostr NIP-01 Kryptographie (secp256k1 + BIP-340 Schnorr Signaturen)
/// sowie AES-256-GCM Haushalts-Verschlüsselung für Bestands- und Log-Events.
class NostrCrypto {
  static final ECDomainParameters _secp256k1 = ECDomainParameters('secp256k1');
  static final BigInt _p = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
    radix: 16,
  );
  static final BigInt _n = _secp256k1.n;

  /// Erzeugt ein neues 32-Byte Private-Key Hex-String (64 Zeichen) + X-only Pubkey (64 Zeichen).
  static Map<String, String> generateKeyPair() {
    final rng = Random.secure();
    BigInt d;
    do {
      final bytes = Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
      d = _bytesToBigInt(bytes);
    } while (d <= BigInt.zero || d >= _n);

    final privHex = _bigIntToHex32(d);
    final pubHex = getPublicKey(privHex);
    return {
      'privkey': privHex,
      'pubkey': pubHex,
    };
  }

  /// Berechnet den 32-Byte X-only Public Key (BIP-340) aus einem 64-Zeichen Hex Private Key.
  static String getPublicKey(String privkeyHex) {
    final d = BigInt.parse(privkeyHex, radix: 16);
    final P = (_secp256k1.G * d)!;
    final x = P.x!.toBigInteger()!;
    return _bigIntToHex32(x);
  }

  /// Berechnet die Nostr Event-ID (NIP-01): SHA256 über [0, pubkey, created_at, kind, tags, content]
  static String computeEventId({
    required String pubkey,
    required int createdAt,
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) {
    final serialized = jsonEncode([
      0,
      pubkey.toLowerCase(),
      createdAt,
      kind,
      tags,
      content,
    ]);
    final digest = sha256.convert(utf8.encode(serialized));
    return digest.toString();
  }

  /// Erzeugt eine BIP-340 Schnorr-Signatur (64 Bytes = 128 Hex-Zeichen) über eine 32-Byte Event-ID.
  static String signEventId(String eventIdHex, String privkeyHex) {
    final d0 = BigInt.parse(privkeyHex, radix: 16);
    final P = (_secp256k1.G * d0)!;
    final px = P.x!.toBigInteger()!;
    final py = P.y!.toBigInteger()!;

    // BIP-340: Wenn P.y ungerade ist, negiere d modulo n
    final d = py.isEven ? d0 : (_n - d0);

    final msgBytes = Uint8List.fromList(hex.decode(eventIdHex));
    final dBytes = _bigIntToBytes32(d);
    final pxBytes = _bigIntToBytes32(px);

    // Deterministischer Aux-Zufallswert
    final auxRand = sha256.convert([...dBytes, ...msgBytes]).bytes;
    final auxHash = _taggedHash('BIP0340/aux', Uint8List.fromList(auxRand));

    final t = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      t[i] = dBytes[i] ^ auxHash[i];
    }

    final rand = _taggedHash(
      'BIP0340/nonce',
      Uint8List.fromList([...t, ...pxBytes, ...msgBytes]),
    );
    final k0 = _bytesToBigInt(rand) % _n;
    if (k0 == BigInt.zero) {
      throw StateError('Ungültiges Nonce k0');
    }

    final R = (_secp256k1.G * k0)!;
    final rx = R.x!.toBigInteger()!;
    final ry = R.y!.toBigInteger()!;
    final k = ry.isEven ? k0 : (_n - k0);

    final rxBytes = _bigIntToBytes32(rx);
    final eHash = _taggedHash(
      'BIP0340/challenge',
      Uint8List.fromList([...rxBytes, ...pxBytes, ...msgBytes]),
    );
    final e = _bytesToBigInt(eHash) % _n;

    final s = (k + (e * d)) % _n;
    final sigBytes = Uint8List.fromList([...rxBytes, ..._bigIntToBytes32(s)]);
    return hex.encode(sigBytes);
  }

  /// Verifiziert eine BIP-340 Schnorr-Signatur.
  static bool verifySignature(String eventIdHex, String pubkeyHex, String sigHex) {
    try {
      if (sigHex.length != 128 || pubkeyHex.length != 64 || eventIdHex.length != 64) {
        return false;
      }
      final px = BigInt.parse(pubkeyHex, radix: 16);
      if (px >= _p) return false;

      final P = _liftX(px);
      if (P == null) return false;

      final r = BigInt.parse(sigHex.substring(0, 64), radix: 16);
      final s = BigInt.parse(sigHex.substring(64, 128), radix: 16);
      if (r >= _p || s >= _n) return false;

      final rxBytes = _bigIntToBytes32(r);
      final pxBytes = _bigIntToBytes32(px);
      final msgBytes = Uint8List.fromList(hex.decode(eventIdHex));

      final eHash = _taggedHash(
        'BIP0340/challenge',
        Uint8List.fromList([...rxBytes, ...pxBytes, ...msgBytes]),
      );
      final e = _bytesToBigInt(eHash) % _n;

      final sG = (_secp256k1.G * s)!;
      final eP = (P * (_n - e))!;
      final R = (sG + eP)!;
      if (R.isInfinity) return false;

      final rx = R.x!.toBigInteger()!;
      final ry = R.y!.toBigInteger()!;
      return ry.isEven && rx == r;
    } catch (_) {
      return false;
    }
  }

  /// Verschlüsselt einen JSON-String mit dem gemeinsamen Haushalts-Schlüssel (AES-256-GCM).
  static String encryptForHousehold(String plaintext, String householdPrivkeyHex) {
    final keyBytes = Uint8List.fromList(
      sha256.convert(utf8.encode('eiszeit-household-v1:$householdPrivkeyHex')).bytes,
    );
    final rng = Random.secure();
    final nonce = Uint8List.fromList(List<int>.generate(12, (_) => rng.nextInt(256)));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(keyBytes),
          128,
          nonce,
          Uint8List(0),
        ),
      );

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final cipherBytes = cipher.process(input);

    final combined = Uint8List.fromList([...nonce, ...cipherBytes]);
    return 'ez1:${base64Encode(combined)}';
  }

  /// Entschlüsselt einen mit `encryptForHousehold` verschlüsselten Payload.
  static String? decryptFromHousehold(String payload, String householdPrivkeyHex) {
    try {
      if (!payload.startsWith('ez1:')) return null;
      final raw = base64Decode(payload.substring(4));
      if (raw.length < 28) return null;

      final nonce = Uint8List.sublistView(raw, 0, 12);
      final cipherBytes = Uint8List.sublistView(raw, 12);

      final keyBytes = Uint8List.fromList(
        sha256.convert(utf8.encode('eiszeit-household-v1:$householdPrivkeyHex')).bytes,
      );

      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(keyBytes),
            128,
            nonce,
            Uint8List(0),
          ),
        );

      final plainBytes = cipher.process(cipherBytes);
      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _taggedHash(String tag, Uint8List msg) {
    final tagHash = sha256.convert(utf8.encode(tag)).bytes;
    final digest = sha256.convert([...tagHash, ...tagHash, ...msg]);
    return Uint8List.fromList(digest.bytes);
  }

  static ECPoint? _liftX(BigInt x) {
    if (x <= BigInt.zero || x >= _p) return null;
    final c = (x.modPow(BigInt.from(3), _p) + BigInt.from(7)) % _p;
    final y = c.modPow((_p + BigInt.one) >> 2, _p);
    if ((y * y) % _p != c) return null;
    final evenY = y.isEven ? y : (_p - y);
    return _secp256k1.curve.createPoint(x, evenY);
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static Uint8List _bigIntToBytes32(BigInt value) {
    final hexStr = value.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(hex.decode(hexStr));
  }

  static String _bigIntToHex32(BigInt value) {
    return value.toRadixString(16).padLeft(64, '0');
  }
}
