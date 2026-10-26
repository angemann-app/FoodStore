import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/app_state.dart';
import '../services/update_service.dart';

class UpdateCenterDialog extends StatelessWidget {
  final AppState appState;

  const UpdateCenterDialog({
    super.key,
    required this.appState,
  });

  static Future<void> show(BuildContext context, {required AppState appState}) {
    // Wenn noch nie geprüft wurde, beim Öffnen direkt eine Prüfung anstoßen
    if (appState.latestUpdateResult == null && !appState.isCheckingForUpdates) {
      appState.checkForUpdatesNow();
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdateCenterDialog(appState: appState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateTimeFmt = DateFormat('dd.MM.yyyy • HH:mm');

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final channel = appState.updateChannel;
        final result = appState.latestUpdateResult;
        final release = result?.latestRelease;
        final isChecking = appState.isCheckingForUpdates;
        final hasUpdate = appState.isUpdateAvailable;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header mit Eiszeit-Mammut & Versions-Badge
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/eiszeit_app_icon.jpg',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.system_update_rounded,
                          size: 40,
                          color: Color(0xFF005691),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Eiszeit Update-Center',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF005691).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Installiert: v${UpdateService.currentAppVersion}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF005691),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'GitHub: ${UpdateService.githubOwner}/${UpdateService.githubRepo}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 1. Update-Kanal Auswahl (Stable vs. Beta)
                const Text(
                  'Update-Kanal wählen:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<UpdateChannel>(
                  segments: const [
                    ButtonSegment<UpdateChannel>(
                      value: UpdateChannel.stable,
                      icon: Icon(Icons.verified_outlined),
                      label: Text('Stable (Stabil)'),
                    ),
                    ButtonSegment<UpdateChannel>(
                      value: UpdateChannel.beta,
                      icon: Icon(Icons.science_outlined),
                      label: Text('Beta (Vorab)'),
                    ),
                  ],
                  selected: {channel},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      appState.setUpdateChannel(selection.first);
                    }
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  channel.description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.blueGrey.shade600,
                  ),
                ),

                // 2. Täglicher Auto-Check Schalter
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Täglich automatisch auf neue Versionen prüfen',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    appState.lastUpdateCheck != null
                        ? 'Zuletzt geprüft: ${dateTimeFmt.format(appState.lastUpdateCheck!)} Uhr'
                        : 'Noch keine automatische Prüfung durchgeführt',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  value: appState.autoCheckUpdatesDaily,
                  onChanged: (val) => appState.setAutoCheckUpdatesDaily(val),
                ),
                const Divider(height: 18),

                // 3. Ergebnis-Anzeige der Update-Prüfung
                if (isChecking)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Prüfe GitHub Releases auf neue Versionen…',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                else if (result?.error != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            result!.error!,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (release == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      channel == UpdateChannel.stable
                          ? 'Aktuell liegt noch kein finales Stable-Release auf GitHub vor. Wechsle auf den Beta-Kanal, um Vorabversionen zu erhalten.'
                          : 'Noch keine Releases im gewählten Kanal gefunden.',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasUpdate
                            ? [const Color(0xFFE8F5E9), const Color(0xFFFFFFFF)]
                            : [const Color(0xFFF1F8FE), const Color(0xFFFFFFFF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasUpdate
                            ? Colors.green.shade400
                            : Colors.blue.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasUpdate
                                  ? Icons.new_releases_rounded
                                  : Icons.check_circle_rounded,
                              color: hasUpdate
                                  ? Colors.green.shade700
                                  : const Color(0xFF005691),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasUpdate
                                    ? 'Neue Version verfügbar: ${release.tagName}'
                                    : 'App ist aktuell (${release.tagName})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: hasUpdate
                                      ? Colors.green.shade800
                                      : const Color(0xFF005691),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: release.isPrerelease
                                    ? Colors.deepOrange
                                    : Colors.green.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                release.isPrerelease ? 'BETA' : 'STABLE',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${release.title} • Veröffentlicht am ${dateTimeFmt.format(release.publishedAt.toLocal())}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (release.releaseNotes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 130),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blueGrey.shade100),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                release.releaseNotes,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: hasUpdate
                                      ? Colors.green.shade700
                                      : const Color(0xFF005691),
                                ),
                                onPressed: () async {
                                  final targetUrl = release.downloadOrReleaseUrl;
                                  final launched =
                                      await UpdateService.openReleaseOrApkUrl(targetUrl);
                                  if (!launched && context.mounted) {
                                    Clipboard.setData(ClipboardData(text: targetUrl));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Download-Link kopiert: $targetUrl',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(
                                  release.apkDownloadUrl != null
                                      ? Icons.download_rounded
                                      : Icons.open_in_new_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  release.apkDownloadUrl != null
                                      ? (hasUpdate
                                          ? 'APK jetzt herunterladen ${release.formattedSize.isNotEmpty ? "(${release.formattedSize})" : ""}'
                                          : 'APK erneut herunterladen')
                                      : 'GitHub Release öffnen',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Release-Link kopieren',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: release.downloadOrReleaseUrl),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Download-/Release-Link kopiert!'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // 4. Händischer "Jetzt prüfen"-Knopf
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isChecking
                            ? null
                            : () => appState.checkForUpdatesNow(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Jetzt händisch auf Updates prüfen'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Schließen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
