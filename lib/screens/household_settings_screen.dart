import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/nostr_models.dart';
import '../services/app_state.dart';
import '../services/nostr_service.dart';
import '../services/update_service.dart';
import '../widgets/update_center_dialog.dart';

class HouseholdSettingsScreen extends StatefulWidget {
  final AppState appState;

  const HouseholdSettingsScreen({
    super.key,
    required this.appState,
  });

  @override
  State<HouseholdSettingsScreen> createState() => _HouseholdSettingsScreenState();
}

class _HouseholdSettingsScreenState extends State<HouseholdSettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _r2AccountCtrl;
  late TextEditingController _r2BucketCtrl;
  late TextEditingController _r2AccessKeyCtrl;
  late TextEditingController _r2SecretKeyCtrl;
  late TextEditingController _r2PublicUrlCtrl;
  late TextEditingController _newRelayCtrl;
  bool _shareR2WithHousehold = true;
  bool _showSecretKeys = false;

  @override
  void initState() {
    super.initState();
    final state = widget.appState;
    _nameCtrl = TextEditingController(text: state.currentUser.displayName);
    final r2 = state.household.r2Config;
    _r2AccountCtrl = TextEditingController(text: r2.accountId);
    _r2BucketCtrl = TextEditingController(text: r2.bucketName);
    _r2AccessKeyCtrl = TextEditingController(text: r2.accessKeyId);
    _r2SecretKeyCtrl = TextEditingController(text: r2.secretAccessKey);
    _r2PublicUrlCtrl = TextEditingController(text: r2.publicBaseUrl);
    _shareR2WithHousehold = r2.shareWithHousehold;
    _newRelayCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _r2AccountCtrl.dispose();
    _r2BucketCtrl.dispose();
    _r2AccessKeyCtrl.dispose();
    _r2SecretKeyCtrl.dispose();
    _r2PublicUrlCtrl.dispose();
    _newRelayCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddFamilyMemberDialog() async {
    final appState = widget.appState;
    final memberNameCtrl = TextEditingController();
    final pubkeyCtrl = TextEditingController();
    HouseholdRole selectedRole = HouseholdRole.member;
    String selectedColor = '#00897B';

    const colors = [
      '#0288D1',
      '#00897B',
      '#7B1FA2',
      '#E65100',
      '#C2185B',
      '#388E3C',
    ];

    final inviteResult = await showDialog<PendingMemberInvite>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canAssignSecondAdmin = appState.household.hasOpenAdminSlot;
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: Color(0xFF005691)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Familienmitglied neu aufnehmen',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Als Host/Admin nimmst du ein neues Familienmitglied in die Liste auf und erzeugst direkt einen Einladungs-QR-Code.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: memberNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name des Familienmitglieds *',
                        hintText: 'z. B. Anna, Max, Oma',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<HouseholdRole>(
                      initialValue: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Rolle im Haushalt (Admin max. 2 Personen)',
                        border: const OutlineInputBorder(),
                        helperText: canAssignSecondAdmin
                            ? 'Noch 1 von 2 Admin-Plätzen frei.'
                            : 'Beide Admin-Plätze (2/2) sind bereits vergeben.',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: HouseholdRole.member,
                          child: Text('Familienmitglied (Ein-/Auslagern)'),
                        ),
                        if (canAssignSecondAdmin)
                          const DropdownMenuItem(
                            value: HouseholdRole.host,
                            child: Text('2. Host / Admin (Mitglieder & Einstellungen)'),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pubkeyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vorhandener Nostr Hex-Pubkey (optional)',
                        hintText: 'Leer lassen = Schlüssel automatisch erzeugen',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Profilfarbe wählen:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: colors.map((hexColor) {
                        final isSelected = selectedColor == hexColor;
                        final color = _parseHexColor(hexColor);
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = hexColor),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: color,
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final name = memberNameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final invite = await appState.addFamilyMemberByHost(
                      memberName: name,
                      existingPubkey: pubkeyCtrl.text.trim(),
                      colorHex: selectedColor,
                      role: selectedRole,
                    );
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop(invite);
                  },
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Aufnehmen & QR-Einladung zeigen'),
                ),
              ],
            );
          },
        );
      },
    );

    if (inviteResult != null && mounted) {
      await _showInviteQrModal(
        title: 'Einladung für ${inviteResult.member.displayName}',
        subtitle: inviteResult.member.role == HouseholdRole.host
            ? 'Rolle: 2. Host / Admin • Scanne diesen QR-Code in der Eiszeit-App'
            : 'Rolle: Familienmitglied • Scanne diesen QR-Code in der Eiszeit-App',
        qrPayload: inviteResult.qrPayload,
      );
    }
  }

  Future<void> _showInviteQrModal({
    required String title,
    required String subtitle,
    required String qrPayload,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 230,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: qrPayload));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Einladungs-Code in die Zwischenablage kopiert!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Einladungs-Code kopieren'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Fertig'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showJoinHouseholdDialog() async {
    final codeCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Haushalts-Einladung annehmen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Scanne den QR-Code vom Host/Admin oder füge den kopierten eiszeit:// Einladungs-Code hier ein.',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: MobileScanner(
                    onDetect: (capture) async {
                      for (final barcode in capture.barcodes) {
                        final raw = barcode.rawValue;
                        if (raw != null && raw.startsWith('eiszeit://')) {
                          final ok = await widget.appState.acceptHouseholdInvite(raw);
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Erfolgreich dem Haushalt beigetreten!'
                                    : 'Ungültiger Einladungs-Code.',
                              ),
                            ),
                          );
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Oder Einladungs-Code (eiszeit://...) einfügen',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await widget.appState.acceptHouseholdInvite(codeCtrl.text);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Erfolgreich dem Haushalt beigetreten!'
                            : 'Einladungs-Code konnte nicht gelesen werden.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Einladung übernehmen'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final household = appState.household;
    final isHost = appState.isCurrentUserHost;
    final members = household.activeMembers;
    final relayStatuses = appState.nostrService.relayStatuses;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
      children: [
        // 1. FAMILIENMITGLIEDER-LISTE & 2-PERSONEN-ADMIN-VERWALTUNG
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF005691).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.groups_rounded, color: Color(0xFF005691)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Familienmitglieder & Hosts',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Admin-Posten: ${household.adminCount}/${HouseholdConfig.maxAdmins} Personen besetzt • ${members.length} aktive Mitglieder',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 18, color: Color(0xFF005691)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHost
                              ? 'Du bist Host/Admin (${household.adminCount}/2). Du kannst neue Familienmitglieder in die Liste aufnehmen und bis zu 1 weiteren Co-Admin ernennen.'
                              : 'Du bist eingeladenes Familienmitglied. Die ${household.adminCount} Hosts/Admins verwalten die Mitgliederliste.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Mitglieder-Liste
                ...members.map((member) {
                  final memberIsAdmin = household.isHost(member.pubkey);
                  final isFounder = member.pubkey == household.hostPubkey;
                  final isSelf = member.pubkey == appState.currentUser.pubkey;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: memberIsAdmin
                            ? const Color(0xFF005691).withValues(alpha: 0.35)
                            : Colors.blueGrey.shade100,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: _parseHexColor(member.colorHex),
                        child: Text(
                          member.displayName.isNotEmpty
                              ? member.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              isSelf ? '${member.displayName} (Du)' : member.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: memberIsAdmin
                                  ? const Color(0xFF005691)
                                  : Colors.blueGrey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isFounder
                                  ? '1. Host / Admin'
                                  : memberIsAdmin
                                      ? '2. Host / Admin'
                                      : 'Mitglied',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: memberIsAdmin ? Colors.white : Colors.blueGrey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        member.shortPubkey,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                      trailing: isHost
                          ? PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'qr') {
                                  final payload = household.toInviteQrPayload(
                                    preAssignedMemberName: member.displayName,
                                    preAssignedMemberPubkey: member.pubkey,
                                    assignedRole: memberIsAdmin
                                        ? HouseholdRole.host
                                        : HouseholdRole.member,
                                  );
                                  await _showInviteQrModal(
                                    title: 'Einladungs-QR für ${member.displayName}',
                                    subtitle: 'Scanne diesen Code auf dem Handy von ${member.displayName}',
                                    qrPayload: payload,
                                  );
                                } else if (action == 'toggle_admin') {
                                  try {
                                    await appState.toggleSecondAdminRole(member);
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                } else if (action == 'remove') {
                                  await appState.removeFamilyMemberByHost(member.pubkey);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'qr',
                                  child: Row(
                                    children: [
                                      Icon(Icons.qr_code, size: 18),
                                      SizedBox(width: 8),
                                      Text('Einladungs-QR-Code zeigen'),
                                    ],
                                  ),
                                ),
                                if (!isFounder)
                                  PopupMenuItem(
                                    value: 'toggle_admin',
                                    enabled: memberIsAdmin || household.hasOpenAdminSlot,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.admin_panel_settings_outlined, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          memberIsAdmin
                                              ? '2. Admin-Status entziehen'
                                              : 'Zum 2. Host/Admin ernennen',
                                        ),
                                      ],
                                    ),
                                  ),
                                if (!isFounder)
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text(
                                          'Aus Liste entfernen',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            )
                          : null,
                    ),
                  );
                }),

                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (isHost)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF005691),
                        ),
                        onPressed: _showAddFamilyMemberDialog,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Familienmitglied aufnehmen & einladen'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _showJoinHouseholdDialog,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Einladung scannen / Beitreten'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2. CLOUDFLARE R2 BILDER-SPEICHER
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_upload_outlined, color: Colors.deepOrange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cloudflare R2 Bilder-Speicher',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            household.r2Config.isConfigured
                                ? 'Aktiviert • Bucket: ${household.r2Config.bucketName}'
                                : 'Noch nicht hinterlegt • Fotos werden vorerst lokal/Nostr-kompakt gespeichert',
                            style: TextStyle(
                              fontSize: 12,
                              color: household.r2Config.isConfigured
                                  ? Colors.green.shade700
                                  : Colors.blueGrey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _r2AccountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cloudflare Account ID',
                    hintText: 'z. B. 8f9a2b3c4d5e6f7a8b9c0d1e2f3a4b5c',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _r2BucketCtrl,
                        decoration: const InputDecoration(
                          labelText: 'R2 Bucket Name',
                          hintText: 'z. B. foodstore-images',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _r2PublicUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Public URL / r2.dev Domain',
                          hintText: 'https://pub-xxx.r2.dev',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _r2AccessKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'S3 Access Key ID',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _r2SecretKeyCtrl,
                  obscureText: !_showSecretKeys,
                  decoration: InputDecoration(
                    labelText: 'S3 Secret Access Key',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(_showSecretKeys ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showSecretKeys = !_showSecretKeys),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'R2-Zugang verschlüsselt mit Haushalt teilen',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'So können alle Familienmitglieder beim Einlagern Fotos auf R2 hochladen.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _shareR2WithHousehold,
                  onChanged: (val) => setState(() => _shareR2WithHousehold = val),
                ),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        final cfg = R2Config(
                          accountId: _r2AccountCtrl.text.trim(),
                          bucketName: _r2BucketCtrl.text.trim(),
                          accessKeyId: _r2AccessKeyCtrl.text.trim(),
                          secretAccessKey: _r2SecretKeyCtrl.text.trim(),
                          publicBaseUrl: _r2PublicUrlCtrl.text.trim(),
                          shareWithHousehold: _shareR2WithHousehold,
                        );
                        await appState.updateR2Config(cfg);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cloudflare R2 Einstellungen gespeichert.')),
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('R2 Speichern'),
                    ),
                    const SizedBox(width: 10),
                    if (household.r2Config.isConfigured && appState.pendingR2UploadCount > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: appState.isMigratingR2
                              ? null
                              : () async {
                                  final count = await appState.migratePendingImagesToR2();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$count Bilder zu Cloudflare R2 migriert!'),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.cloud_sync_outlined),
                          label: Text(
                            '${appState.pendingR2UploadCount} Bilder zu R2 laden',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. EIGENES NOSTR-PROFIL & RELAYS
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dein Nostr-Profil & Relays',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dein Anzeigename im Haushalt',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () async {
                        if (_nameCtrl.text.trim().isEmpty) return;
                        await appState.updateCurrentUserProfile(
                          displayName: _nameCtrl.text.trim(),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profilname aktualisiert.')),
                        );
                      },
                      child: const Text('Speichern'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Dein Nostr Public Key (Hex / npub)'),
                  subtitle: SelectableText(
                    appState.currentUser.pubkey,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: appState.currentUser.pubkey));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Public Key kopiert!')),
                      );
                    },
                  ),
                ),
                const Divider(),
                const Text(
                  'Verbundene Nostr Relays:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ...household.relays.map((relayUrl) {
                  final status = relayStatuses[relayUrl];
                  final connected = status?.state == RelayConnectionState.connected;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      Icons.circle,
                      size: 12,
                      color: connected ? Colors.green : Colors.orange,
                    ),
                    title: Text(
                      relayUrl,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    subtitle: Text(
                      connected
                          ? 'Verbunden • Empfangen: ${status?.eventsReceived ?? 0} • Gesendet: ${status?.eventsPublished ?? 0}'
                          : 'Verbinde / Offline-Puffer aktiv',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: household.relays.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () {
                              final updated = household.relays
                                  .where((r) => r != relayUrl)
                                  .toList();
                              appState.updateRelays(updated);
                            },
                          )
                        : null,
                  );
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newRelayCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Weiteres Nostr Relay hinzufügen',
                          hintText: 'wss://relay.example.com',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        final val = _newRelayCtrl.text.trim();
                        if (val.startsWith('wss://') || val.startsWith('ws://')) {
                          appState.updateRelays([...household.relays, val]);
                          _newRelayCtrl.clear();
                        }
                      },
                      child: const Text('+ Relay'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 4. APP-UPDATES & RELEASE-KANAL (STABLE / BETA)
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF005691).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Color(0xFF005691),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'App-Updates (Stable / Beta)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Installiert: v${UpdateService.currentAppVersion} • Kanal: ${appState.updateChannel.label}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (appState.isUpdateAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'UPDATE BEREIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedButton<UpdateChannel>(
                  segments: const [
                    ButtonSegment<UpdateChannel>(
                      value: UpdateChannel.stable,
                      icon: Icon(Icons.verified_outlined, size: 18),
                      label: Text('Stable-Kanal'),
                    ),
                    ButtonSegment<UpdateChannel>(
                      value: UpdateChannel.beta,
                      icon: Icon(Icons.science_outlined, size: 18),
                      label: Text('Beta-Kanal'),
                    ),
                  ],
                  selected: {appState.updateChannel},
                  onSelectionChanged: (sel) {
                    if (sel.isNotEmpty) {
                      appState.setUpdateChannel(sel.first);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Tägliches Prüfen auf neue Versionen',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Prüft automatisch alle 24 Stunden im gewählten Kanal auf GitHub.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: appState.autoCheckUpdatesDaily,
                  onChanged: (val) => appState.setAutoCheckUpdatesDaily(val),
                ),
                Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF005691),
                      ),
                      onPressed: appState.isCheckingForUpdates
                          ? null
                          : () async {
                              await appState.checkForUpdatesNow();
                              if (!context.mounted) return;
                              UpdateCenterDialog.show(context, appState: appState);
                            },
                      icon: appState.isCheckingForUpdates
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Jetzt auf Updates prüfen'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () =>
                          UpdateCenterDialog.show(context, appState: appState),
                      child: const Text('Update-Center öffnen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _parseHexColor(String hexColor) {
    try {
      final clean = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF0288D1);
    }
  }
}
