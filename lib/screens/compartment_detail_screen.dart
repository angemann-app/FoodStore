import 'package:flutter/material.dart';

import '../models/freezer_compartment.dart';
import '../services/app_state.dart';
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
        final items = appState.itemsInCompartment(compartment.id);

        return Scaffold(
          backgroundColor: const Color(0xFFF3F7FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF005691),
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compartment.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  compartment.subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF005691),
            foregroundColor: Colors.white,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddItemSheet(
                  appState: appState,
                  initialCompartmentId: compartment.id,
                ),
              );
            },
            icon: const Icon(Icons.add_box_outlined),
            label: Text('In ${compartment.title} einlagern'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF005691).withValues(alpha: 0.09),
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      compartment.isDoorCompartment
                          ? Icons.door_sliding_outlined
                          : compartment.isBigBox
                              ? Icons.inventory_2_outlined
                              : Icons.kitchen_outlined,
                      color: const Color(0xFF005691),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Empfehlung für ${compartment.title}:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF005691),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            compartment.recommendation,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: Text(
                        '${items.length} Pos.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF005691),
                        ),
                      ),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.ac_unit,
                        size: 48,
                        color: Colors.blue.shade200,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${compartment.title} ist aktuell leer',
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
                    onIncrement: () => appState.adjustItemQuantity(item, 1),
                    onDecrement: () => appState.adjustItemQuantity(item, -1),
                    onRemoveAll: () => appState.adjustItemQuantity(
                      item,
                      -item.quantity,
                      note: 'Aus ${compartment.title} entnommen',
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
