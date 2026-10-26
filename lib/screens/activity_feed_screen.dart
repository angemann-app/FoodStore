import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/freezer_compartment.dart';
import '../models/nostr_models.dart';
import '../services/app_state.dart';

class ActivityFeedScreen extends StatefulWidget {
  final AppState appState;

  const ActivityFeedScreen({
    super.key,
    required this.appState,
  });

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  String? _selectedActorPubkey;

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final members = appState.household.activeMembers;
    final allTransactions = appState.transactions;
    final filtered = _selectedActorPubkey == null
        ? allTransactions
        : allTransactions.where((t) => t.actorPubkey == _selectedActorPubkey).toList();

    final dateFormatter = DateFormat('dd.MM.yyyy • HH:mm');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_outlined, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nostr Aktivitäts-Log ("Rein & Raus")',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Jede Bewegung wird mit dem persönlichen Nostr-Schlüssel signiert und verschlüsselt synchronisiert.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Jetzt über Nostr synchronisieren',
                onPressed: () => appState.manualSyncNow(),
                icon: const Icon(Icons.sync, color: Color(0xFF005691)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Filter nach Familienmitglied
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Alle Familienmitglieder'),
                  selected: _selectedActorPubkey == null,
                  onSelected: (_) => setState(() => _selectedActorPubkey = null),
                ),
              ),
              ...members.map((m) {
                final isSelected = _selectedActorPubkey == m.pubkey;
                final isAdmin = appState.household.isHost(m.pubkey);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Icon(
                      isAdmin ? Icons.verified_user : Icons.person,
                      size: 16,
                    ),
                    label: Text(isAdmin ? '${m.displayName} (Admin)' : m.displayName),
                    selected: isSelected,
                    onSelected: (val) =>
                        setState(() => _selectedActorPubkey = val ? m.pubkey : null),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.history, size: 42, color: Colors.blueGrey),
                SizedBox(height: 8),
                Text('Noch keine Aktivitäten für diesen Filter vorhanden.'),
              ],
            ),
          )
        else
          ...filtered.map((tx) {
            final config = _styleForTransaction(tx);
            final compTitle = FreezerCompartment.byId(tx.compartmentId).title;
            final targetTitle = tx.targetCompartmentId != null
                ? FreezerCompartment.byId(tx.targetCompartmentId!).title
                : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: config.color.withValues(alpha: 0.14),
                  child: Icon(config.icon, color: config.color, size: 20),
                ),
                title: Text(
                  _buildHeadline(tx, compTitle, targetTitle),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(
                      '${dateFormatter.format(tx.timestamp)} Uhr • Signiert von ${tx.actorName}',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
                    ),
                    if (tx.note != null && tx.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          tx.note!,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.blueGrey.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _buildHeadline(
    InventoryTransaction tx,
    String compTitle,
    String? targetTitle,
  ) {
    final qtyAbs = tx.quantityDelta.abs();
    final qtyStr = qtyAbs == qtyAbs.roundToDouble()
        ? qtyAbs.toInt().toString()
        : qtyAbs.toStringAsFixed(1);

    switch (tx.type) {
      case TransactionType.checkIn:
        return '${tx.actorName} hat $qtyStr ${tx.unit} "${tx.itemName}" in $compTitle eingelagert';
      case TransactionType.checkOut:
        return '${tx.actorName} hat $qtyStr ${tx.unit} "${tx.itemName}" aus $compTitle entnommen';
      case TransactionType.quantityChange:
        final sign = tx.quantityDelta >= 0 ? '+' : '-';
        return '${tx.actorName} hat "${tx.itemName}" in $compTitle angepasst ($sign$qtyStr ${tx.unit})';
      case TransactionType.moveCompartment:
        return '${tx.actorName} hat "${tx.itemName}" von $compTitle nach ${targetTitle ?? ''} umgeräumt';
      case TransactionType.icePackToggle:
        return '${tx.actorName}: ${tx.itemName} (${tx.note ?? 'Status geändert'})';
      case TransactionType.memberAdded:
        return '${tx.actorName} hat ${tx.itemName} in den Haushalt aufgenommen';
      case TransactionType.memberRemoved:
        return '${tx.actorName} hat ${tx.itemName} aus der Mitgliederliste entfernt';
      case TransactionType.adminChanged:
        return '${tx.actorName} hat Admin-Rechte für ${tx.itemName} aktualisiert';
    }
  }

  ({IconData icon, Color color}) _styleForTransaction(InventoryTransaction tx) {
    switch (tx.type) {
      case TransactionType.checkIn:
        return (icon: Icons.south_east_rounded, color: Colors.green.shade700);
      case TransactionType.checkOut:
        return (icon: Icons.north_east_rounded, color: Colors.red.shade700);
      case TransactionType.quantityChange:
        return (icon: Icons.exposure, color: Colors.teal.shade700);
      case TransactionType.moveCompartment:
        return (icon: Icons.swap_vert_rounded, color: Colors.blue.shade700);
      case TransactionType.icePackToggle:
        return (icon: Icons.ac_unit, color: Colors.indigo.shade600);
      case TransactionType.memberAdded:
      case TransactionType.adminChanged:
        return (icon: Icons.person_add_alt_1, color: Colors.deepPurple);
      case TransactionType.memberRemoved:
        return (icon: Icons.person_remove_alt_1, color: Colors.brown);
    }
  }
}
