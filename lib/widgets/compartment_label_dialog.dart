import 'package:flutter/material.dart';

import '../models/freezer_compartment.dart';
import '../services/app_state.dart';

class CompartmentLabelDialog extends StatefulWidget {
  final AppState appState;
  final FreezerCompartment compartment;

  const CompartmentLabelDialog({
    super.key,
    required this.appState,
    required this.compartment,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    required FreezerCompartment compartment,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompartmentLabelDialog(
        appState: appState,
        compartment: compartment,
      ),
    );
  }

  @override
  State<CompartmentLabelDialog> createState() => _CompartmentLabelDialogState();
}

class _CompartmentLabelDialogState extends State<CompartmentLabelDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _subtitleCtrl;
  late String _selectedColorHex;
  late String _selectedIconKey;

  static const List<String> _paletteHex = [
    '#005691',
    '#D81B60',
    '#2E7D32',
    '#C62828',
    '#6A1B9A',
    '#E65100',
    '#00897B',
    '#0277BD',
    '#EF6C00',
    '#00838F',
  ];

  static const List<Map<String, String>> _iconChoices = [
    {'key': 'berries', 'label': 'Beeren/Obst'},
    {'key': 'vegetables', 'label': 'Gemüse'},
    {'key': 'meat', 'label': 'Fleisch'},
    {'key': 'fish', 'label': 'Fisch'},
    {'key': 'bread', 'label': 'Brot'},
    {'key': 'cooked', 'label': 'Gekochtes'},
    {'key': 'pizza', 'label': 'Pizza'},
    {'key': 'icecream', 'label': 'Eis'},
    {'key': 'herbs', 'label': 'Kräuter'},
    {'key': 'bigbox', 'label': 'Box/Vorrat'},
    {'key': 'snowflake', 'label': 'Kühlung'},
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.appState.household.compartmentLabels[widget.compartment.id];
    _titleCtrl = TextEditingController(
      text: existing?.themeTitle ?? widget.compartment.title,
    );
    _subtitleCtrl = TextEditingController(
      text: existing?.themeSubtitle ?? widget.compartment.subtitle,
    );
    _selectedColorHex = existing?.colorHex ?? '#005691';
    _selectedIconKey = existing?.iconKey ?? 'snowflake';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  Color _parseHex(String hexStr) {
    try {
      final clean = hexStr.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF005691);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _parseHex(_selectedColorHex);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
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

              // Live-Vorschau des Schubladen-Etiketts
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      activeColor,
                      activeColor.withValues(alpha: 0.82),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        CompartmentCustomLabel.iconFromKey(_selectedIconKey),
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${widget.compartment.slotBadge} • ETIKETT-VORSCHAU',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _titleCtrl.text.trim().isEmpty
                                ? 'Unbeschriftetes Fach'
                                : _titleCtrl.text.trim(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_subtitleCtrl.text.trim().isNotEmpty)
                            Text(
                              _subtitleCtrl.text.trim(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Schnellwahl: Thematische Sortier-Vorlagen',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: CompartmentCustomLabel.thematicPresets.map((preset) {
                  final presetColor = _parseHex(preset['colorHex']!);
                  return ActionChip(
                    avatar: Icon(
                      CompartmentCustomLabel.iconFromKey(preset['iconKey']!),
                      size: 16,
                      color: presetColor,
                    ),
                    label: Text(
                      preset['title']!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: presetColor.withValues(alpha: 0.08),
                    side: BorderSide(color: presetColor.withValues(alpha: 0.3)),
                    onPressed: () {
                      setState(() {
                        _titleCtrl.text = preset['title']!;
                        _subtitleCtrl.text = preset['subtitle']!;
                        _selectedColorHex = preset['colorHex']!;
                        _selectedIconKey = preset['iconKey']!;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _titleCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Eigene Schubladen-Beschriftung (Thema) *',
                  hintText: 'z. B. Fleisch & Grillgut, Beeren & Obst, Suppen…',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _subtitleCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Untertitel / Hinweis (optional)',
                  hintText: 'z. B. Nur Hähnchen, Rind & Bratwürste',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.short_text),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Etikett-Farbe & Symbol:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _paletteHex.map((hex) {
                  final c = _parseHex(hex);
                  final selected = _selectedColorHex.toLowerCase() == hex.toLowerCase();
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black87 : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _iconChoices.map((choice) {
                    final key = choice['key']!;
                    final selected = _selectedIconKey == key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(
                          CompartmentCustomLabel.iconFromKey(key),
                          size: 16,
                          color: selected ? Colors.white : activeColor,
                        ),
                        label: Text(
                          choice['label']!,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: selected,
                        selectedColor: activeColor,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() => _selectedIconKey = key),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  if (widget.compartment.hasCustomLabel)
                    TextButton.icon(
                      onPressed: () async {
                        await widget.appState.resetCompartmentLabel(widget.compartment.id);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Standard'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: activeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: () async {
                      final title = _titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      await widget.appState.updateCompartmentLabel(
                        CompartmentCustomLabel(
                          compartmentId: widget.compartment.id,
                          themeTitle: title,
                          themeSubtitle: _subtitleCtrl.text.trim(),
                          colorHex: _selectedColorHex,
                          iconKey: _selectedIconKey,
                        ),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Etikett speichern & Nostr Sync'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
