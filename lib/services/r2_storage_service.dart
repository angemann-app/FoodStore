import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../models/nostr_models.dart';

class ProcessedImageResult {
  final Uint8List compressedJpegBytes;
  final String thumbnailBase64;
  final String? uploadedR2Url;
  final String? uploadError;

  const ProcessedImageResult({
    required this.compressedJpegBytes,
    required this.thumbnailBase64,
    this.uploadedR2Url,
    this.uploadError,
  });
}

/// Cloudflare R2 (S3-kompatibler Objekt-Speicher) Service mit AWS Signature V4
/// und automatischem Fallback auf lokale/Inline-Vorschaubilder.
class R2StorageService {
  /// Komprimiert ein aufgenommenes Foto, erzeugt ein kompaktes Nostr-Vorschaubild
  /// und lädt das Bild – falls R2 bereits konfiguriert ist – direkt in den Cloudflare R2 Bucket hoch.
  static Future<ProcessedImageResult> processAndUploadImage({
    required Uint8List rawBytes,
    required String itemId,
    required R2Config r2Config,
  }) async {
    Uint8List jpegBytes = rawBytes;
    String thumbBase64 = '';

    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        // 1. Kompaktes Thumbnail (max. 160px) für sofortige Nostr-Synchronisation (Fallback ohne R2)
        final thumb = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 160 : null,
          height: decoded.height > decoded.width ? 160 : null,
        );
        final thumbBytes = Uint8List.fromList(img.encodeJpg(thumb, quality: 68));
        thumbBase64 = base64Encode(thumbBytes);

        // 2. Optimiertes Hauptbild (max. 1024px) für Cloudflare R2
        final resizedMain = (decoded.width > 1024 || decoded.height > 1024)
            ? img.copyResize(
                decoded,
                width: decoded.width >= decoded.height ? 1024 : null,
                height: decoded.height > decoded.width ? 1024 : null,
              )
            : decoded;
        jpegBytes = Uint8List.fromList(img.encodeJpg(resizedMain, quality: 84));
      } else {
        thumbBase64 = base64Encode(rawBytes);
      }
    } catch (_) {
      thumbBase64 = base64Encode(rawBytes);
    }

    if (!r2Config.isConfigured) {
      return ProcessedImageResult(
        compressedJpegBytes: jpegBytes,
        thumbnailBase64: thumbBase64,
      );
    }

    try {
      final objectKey = 'eiszeit/items/$itemId.jpg';
      final url = await uploadBytesToR2(
        bytes: jpegBytes,
        objectKey: objectKey,
        contentType: 'image/jpeg',
        r2Config: r2Config,
      );
      return ProcessedImageResult(
        compressedJpegBytes: jpegBytes,
        thumbnailBase64: thumbBase64,
        uploadedR2Url: url,
      );
    } catch (e) {
      return ProcessedImageResult(
        compressedJpegBytes: jpegBytes,
        thumbnailBase64: thumbBase64,
        uploadError: e.toString(),
      );
    }
  }

  /// Lädt Binärdaten per S3 PUT Request mit AWS Signature V4 (`AWS4-HMAC-SHA256`) zu Cloudflare R2 hoch.
  static Future<String> uploadBytesToR2({
    required Uint8List bytes,
    required String objectKey,
    required String contentType,
    required R2Config r2Config,
  }) async {
    if (!r2Config.isConfigured) {
      throw StateError('Cloudflare R2 ist noch nicht konfiguriert.');
    }

    final host = r2Config.endpointHost;
    final bucket = r2Config.bucketName.trim();
    final cleanKey = objectKey.startsWith('/') ? objectKey.substring(1) : objectKey;
    final canonicalUri = '/$bucket/$cleanKey';
    final endpointUri = Uri.parse('https://$host$canonicalUri');

    final nowUtc = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(nowUtc);
    final dateStamp = amzDate.substring(0, 8);
    const region = 'auto';
    const service = 's3';

    final payloadHash = sha256.convert(bytes).toString();

    final canonicalHeaders = 'content-type:$contentType\n'
        'host:$host\n'
        'x-amz-content-sha256:$payloadHash\n'
        'x-amz-date:$amzDate\n';
    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest = [
      'PUT',
      canonicalUri,
      '',
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSignatureKey(
      r2Config.secretAccessKey.trim(),
      dateStamp,
      region,
      service,
    );
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    final authorizationHeader = 'AWS4-HMAC-SHA256 '
        'Credential=${r2Config.accessKeyId.trim()}/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    final response = await http
        .put(
          endpointUri,
          headers: {
            'Content-Type': contentType,
            'Host': host,
            'x-amz-content-sha256': payloadHash,
            'x-amz-date': amzDate,
            'Authorization': authorizationHeader,
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('R2 Upload fehlgeschlagen (HTTP ${response.statusCode}): ${response.body}');
    }

    return r2Config.resolvePublicUrl(cleanKey);
  }

  static List<int> _hmacSha256(List<int> key, String data) {
    return Hmac(sha256, key).convert(utf8.encode(data)).bytes;
  }

  static List<int> _getSignatureKey(
    String secretKey,
    String dateStamp,
    String regionName,
    String serviceName,
  ) {
    final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), dateStamp);
    final kRegion = _hmacSha256(kDate, regionName);
    final kService = _hmacSha256(kRegion, serviceName);
    return _hmacSha256(kService, 'aws4_request');
  }

  static String _formatAmzDate(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}T'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }
}
