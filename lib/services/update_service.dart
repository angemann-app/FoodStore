import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum UpdateChannel {
  stable,
  beta;

  String get label =>
      this == UpdateChannel.stable ? 'Stable (Stabil)' : 'Beta (Vorabversionen)';

  String get description => this == UpdateChannel.stable
      ? 'Nur fertige, stabile Hauptversionen installieren.'
      : 'Neue Funktionen & Verbesserungen sofort als Beta-Release testen.';
}

class ReleaseInfo {
  final String tagName;
  final String version;
  final String title;
  final String releaseNotes;
  final bool isPrerelease;
  final DateTime publishedAt;
  final String htmlUrl;
  final String? apkDownloadUrl;
  final String? apkFileName;
  final int? apkSizeBytes;

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.title,
    required this.releaseNotes,
    required this.isPrerelease,
    required this.publishedAt,
    required this.htmlUrl,
    this.apkDownloadUrl,
    this.apkFileName,
    this.apkSizeBytes,
  });

  String get downloadOrReleaseUrl => apkDownloadUrl ?? htmlUrl;

  String get formattedSize {
    if (apkSizeBytes == null || apkSizeBytes! <= 0) return '';
    final mb = apkSizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateCheckResult {
  final String installedVersion;
  final UpdateChannel channel;
  final ReleaseInfo? latestRelease;
  final bool updateAvailable;
  final DateTime checkedAt;
  final String? error;

  const UpdateCheckResult({
    required this.installedVersion,
    required this.channel,
    this.latestRelease,
    required this.updateAvailable,
    required this.checkedAt,
    this.error,
  });
}

class UpdateService {
  /// Aktuell installierte App-Version
  static const String currentAppVersion = '0.1.0-beta.3';

  static const String githubOwner = 'angemann-app';
  static const String githubRepo = 'FoodStore';
  static const MethodChannel _launcherChannel =
      MethodChannel('de.eiszeit.app/launcher');

  /// Prüft die GitHub Releases von `angemann-app/FoodStore` für den gewählten Kanal (`stable` oder `beta`).
  static Future<UpdateCheckResult> checkForUpdates({
    required UpdateChannel channel,
    String installedVersion = currentAppVersion,
  }) async {
    final now = DateTime.now();
    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$githubOwner/$githubRepo/releases?per_page=25',
      );
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Eiszeit-FoodStore-App/$installedVersion',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          installedVersion: installedVersion,
          channel: channel,
          updateAvailable: false,
          checkedAt: now,
          error: 'GitHub API antwortete mit Status ${response.statusCode}',
        );
      }

      final rawList = jsonDecode(response.body);
      if (rawList is! List) {
        return UpdateCheckResult(
          installedVersion: installedVersion,
          channel: channel,
          updateAvailable: false,
          checkedAt: now,
          error: 'Unerwartetes Antwortformat von GitHub.',
        );
      }

      final candidates = <ReleaseInfo>[];
      for (final item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        if (item['draft'] == true) continue;

        final isPre = item['prerelease'] == true;
        // Im Stable-Kanal werden Beta/Pre-Releases ausgefiltert
        if (channel == UpdateChannel.stable && isPre) {
          continue;
        }

        final tagName = item['tag_name']?.toString().trim() ?? '';
        if (tagName.isEmpty) continue;

        final cleanVersion = _normalizeVersion(tagName);
        final title = item['name']?.toString().trim().isNotEmpty == true
            ? item['name'].toString().trim()
            : tagName;
        final body = item['body']?.toString().trim() ?? '';
        final htmlUrl = item['html_url']?.toString().trim() ??
            'https://github.com/$githubOwner/$githubRepo/releases/tag/$tagName';
        final publishedAt =
            DateTime.tryParse(item['published_at']?.toString() ?? '') ?? now;

        String? apkUrl;
        String? apkName;
        int? apkSize;

        final assets = item['assets'];
        if (assets is List) {
          for (final asset in assets) {
            if (asset is Map<String, dynamic>) {
              final name = asset['name']?.toString() ?? '';
              final dlUrl = asset['browser_download_url']?.toString() ?? '';
              if (name.toLowerCase().endsWith('.apk') && dlUrl.isNotEmpty) {
                apkUrl = dlUrl;
                apkName = name;
                apkSize = (asset['size'] is int) ? asset['size'] as int : null;
                break;
              }
            }
          }
        }

        candidates.add(
          ReleaseInfo(
            tagName: tagName,
            version: cleanVersion,
            title: title,
            releaseNotes: body,
            isPrerelease: isPre,
            publishedAt: publishedAt,
            htmlUrl: htmlUrl,
            apkDownloadUrl: apkUrl,
            apkFileName: apkName,
            apkSizeBytes: apkSize,
          ),
        );
      }

      if (candidates.isEmpty) {
        return UpdateCheckResult(
          installedVersion: installedVersion,
          channel: channel,
          latestRelease: null,
          updateAvailable: false,
          checkedAt: now,
        );
      }

      // Sortiere absteigend nach semantischer Version
      candidates.sort((a, b) => compareVersions(b.version, a.version));
      final latest = candidates.first;
      final isNewer = compareVersions(latest.version, installedVersion) > 0;

      return UpdateCheckResult(
        installedVersion: installedVersion,
        channel: channel,
        latestRelease: latest,
        updateAvailable: isNewer,
        checkedAt: now,
      );
    } catch (e) {
      return UpdateCheckResult(
        installedVersion: installedVersion,
        channel: channel,
        updateAvailable: false,
        checkedAt: now,
        error: 'Verbindungsfehler bei der Update-Prüfung: $e',
      );
    }
  }

  /// Öffnet den APK-Download oder die GitHub-Release-Seite im System-Browser/Installer
  static Future<bool> openReleaseOrApkUrl(String url) async {
    try {
      final result = await _launcherChannel.invokeMethod<bool>(
        'openUrl',
        {'url': url},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Vergleicht zwei SemVer-Versionen inkl. `-beta.X` Suffix.
  /// Gibt `> 0` zurück, wenn `vA > vB`, `< 0` wenn `vA < vB`, und `0` bei Gleichheit.
  static int compareVersions(String vA, String vB) {
    final normA = _normalizeVersion(vA);
    final normB = _normalizeVersion(vB);
    if (normA == normB) return 0;

    final partsA = normA.split('-');
    final partsB = normB.split('-');

    final coreA = partsA.first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final coreB = partsB.first.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final a = i < coreA.length ? coreA[i] : 0;
      final b = i < coreB.length ? coreB[i] : 0;
      if (a != b) return a.compareTo(b);
    }

    // Gleiche Hauptversion (z. B. 0.1.0 vs 0.1.0-beta.2):
    // Eine stabile Version OHNE Pre-Release-Suffix ist immer höher als eine Beta derselben Nummer!
    final preA = partsA.length > 1 ? partsA.sublist(1).join('-') : '';
    final preB = partsB.length > 1 ? partsB.sublist(1).join('-') : '';

    if (preA.isEmpty && preB.isNotEmpty) return 1;
    if (preA.isNotEmpty && preB.isEmpty) return -1;

    // Beide haben ein Pre-Release-Suffix (z. B. beta.3 vs beta.2)
    final numA = _extractTrailingNumber(preA);
    final numB = _extractTrailingNumber(preB);
    if (numA != null && numB != null && numA != numB) {
      return numA.compareTo(numB);
    }
    return preA.compareTo(preB);
  }

  static String _normalizeVersion(String raw) {
    var clean = raw.trim();
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  static int? _extractTrailingNumber(String text) {
    final match = RegExp(r'(\d+)$').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
