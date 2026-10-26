import 'package:flutter/material.dart';

import '../models/freezer_compartment.dart';
import '../services/app_state.dart';
import '../widgets/compartment_label_dialog.dart';
import '../widgets/item_card.dart';
import 'add_item_sheet.dart';

class CompartmentDetailScreen extends StatelessWidget {
  final AppState appState;
  final FreezerCompartment compartment;

  const CompartmentDetailScreen({
    super.key,
    required this.appState,
    required this.compartment,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final resolved = appState.compartmentById(compartment.id);
        final items = appState.itemsInCompartment(resolved.id);
        final themeColor = resolved.accentColor;

        return Scaffold(
          backgroundColor: const Color(0xFFF3F7FA),
          appBar: AppBar(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${resolved.slotBadge} • ${resolved.title}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  resolved.subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Schublade thematisch beschriften',
                onPressed: () => CompartmentLabelDialog.show(
                  context,
                  appState: appState,
                  compartment: resolved,
                ),
                icon: const Icon(Icons.edit_note_rounded),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddItemSheet(
                  appState: appState,
                  initialCompartmentId: resolved.id,
                ),
              );
            },
            icon: const Icon(Icons.add_box_outlined),
            label: Text('In ${resolved.title} einlagern'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeColor.withValues(alpha: 0.12),
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        resolved.themeIcon,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolved.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: themeColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            resolved.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => CompartmentLabelDialog.show(
                        context,
                        appState: appState,
                        compartment: resolved,
                      ),
                      icon: const Icon(Icons.label_outline, size: 16),
                      label: const Text('Beschriften', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        resolved.themeIcon,
                        size: 48,
                        color: themeColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${resolved.title} ist aktuell leer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tippe unten auf "Einlagern", um Gefriergut per Barcode, Foto oder Schnellwahl hinzuzufügen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...items.map(
                  (item) => FreezerItemCard(
                    item: item,
                    customCompartmentTitle: resolved.title,
                    availableCompartments: appState.resolvedCompartments,
                    onIncrement: () => appState.adjustItemQuantity(item, 1),
                    onDecrement: () => appState.adjustItemQuantity(item, -1),
                    onRemoveAll: () => appState.adjustItemQuantity(
                      item,
                      -item.quantity,
                      note: 'Aus ${resolved.title} entnommen',
                    ),
                    onMoveCompartment: (targetId) =>
                        appState.moveItemToCompartment(item, targetId),
                    onToggleIcePack: () => appState.toggleIcePackInUse(item),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
