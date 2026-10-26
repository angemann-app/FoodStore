import 'package:eiszeit/models/freezer_compartment.dart';
import 'package:eiszeit/models/nostr_models.dart';
import 'package:eiszeit/services/nostr_crypto.dart';
import 'package:eiszeit/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NostrCrypto BIP-340 & Household Encryption Tests', () {
    test('generates valid secp256k1 keypair and verifies BIP-340 Schnorr signature', () {
      final pair = NostrCrypto.generateKeyPair();
      final priv = pair['privkey']!;
      final pub = pair['pubkey']!;

      expect(priv.length, 64);
      expect(pub.length, 64);

      final eventId = NostrCrypto.computeEventId(
        pubkey: pub,
        createdAt: 1730000000,
        kind: 30078,
        tags: [
          ['d', 'eiszeit_test']
        ],
        content: 'hello',
      );
      final sig = NostrCrypto.signEventId(eventId, priv);
      expect(sig.length, 128);

      final isValid = NostrCrypto.verifySignature(eventId, pub, sig);
      expect(isValid, isTrue);
    });

    test('encrypts and decrypts household payload with AES-256-GCM', () {
      final householdKeys = NostrCrypto.generateKeyPair();
      const secretJson = '{"item":"Kultur-Heidelbeeren","compartment":"drawer_2"}';

      final encrypted = NostrCrypto.encryptForHousehold(
        secretJson,
        householdKeys['privkey']!,
      );
      expect(encrypted.startsWith('ez1:'), isTrue);

      final decrypted = NostrCrypto.decryptFromHousehold(
        encrypted,
        householdKeys['privkey']!,
      );
      expect(decrypted, equals(secretJson));
    });
  });

  group('Household 2-Person Admin Rule & Siemens Compartments', () {
    test('enforces maximum of 2 admins (Hosts) in household', () {
      final host1 = HouseholdMember(
        pubkey: 'a' * 64,
        displayName: 'Holger',
        role: HouseholdRole.host,
        colorHex: '#0288D1',
        addedAt: DateTime.now(),
        addedByPubkey: 'a' * 64,
      );
      final host2 = HouseholdMember(
        pubkey: 'b' * 64,
        displayName: 'Co-Admin',
        role: HouseholdRole.host,
        colorHex: '#00897B',
        addedAt: DateTime.now(),
        addedByPubkey: 'a' * 64,
      );
      final member3 = HouseholdMember(
        pubkey: 'c' * 64,
        displayName: 'Kind 1',
        role: HouseholdRole.host, // Even if marked host, maxAdmins is 2
        colorHex: '#7B1FA2',
        addedAt: DateTime.now(),
        addedByPubkey: 'a' * 64,
      );

      final config = HouseholdConfig(
        householdId: 'test_hh',
        householdName: 'Siemens NoFrost',
        householdPubkey: 'd' * 64,
        householdPrivkey: 'e' * 64,
        hostPubkey: host1.pubkey,
        hostName: host1.displayName,
        adminPubkeys: [host1.pubkey, host2.pubkey, member3.pubkey],
        members: [host1, host2, member3],
        relays: const ['wss://relay.damus.io'],
      );

      expect(config.adminCount, equals(2));
      expect(config.hasOpenAdminSlot, isFalse);
      expect(config.isHost(host1.pubkey), isTrue);
      expect(config.isHost(host2.pubkey), isTrue);
      expect(config.isHost(member3.pubkey), isFalse);
      expect(config.isMember(member3.pubkey), isTrue);
    });

    test('has 6 Siemens drawers plus 1 door icepack compartment and supports custom thematic labels', () {
      expect(FreezerCompartment.siemensNoFrostCompartments.length, equals(7));
      final bigBox = FreezerCompartment.byId('big_box');
      expect(bigBox.isBigBox, isTrue);
      final door = FreezerCompartment.byId('door_icepacks');
      expect(door.isDoorCompartment, isTrue);

      final customLabels = {
        'drawer_2': const CompartmentCustomLabel(
          compartmentId: 'drawer_2',
          themeTitle: 'Beeren, Obst & Smoothies',
          themeSubtitle: 'Frühstücks-Schublade',
          colorHex: '#D81B60',
          iconKey: 'berries',
        ),
      };
      final resolved = FreezerCompartment.byId('drawer_2', customLabels);
      expect(resolved.hasCustomLabel, isTrue);
      expect(resolved.title, equals('Beeren, Obst & Smoothies'));
      expect(resolved.subtitle, equals('Frühstücks-Schublade'));
    });

    test('compares Stable and Beta versions accurately', () {
      expect(
        UpdateService.compareVersions('v0.1.0-beta.3', 'v0.1.0-beta.2'),
        greaterThan(0),
      );
      expect(
        UpdateService.compareVersions('v0.1.0', 'v0.1.0-beta.3'),
        greaterThan(0),
      );
      expect(
        UpdateService.compareVersions('v0.2.0-beta.1', 'v0.1.0'),
        greaterThan(0),
      );
      expect(
        UpdateService.compareVersions('0.1.0-beta.3', 'v0.1.0-beta.3'),
        equals(0),
      );
    });
  });
}
