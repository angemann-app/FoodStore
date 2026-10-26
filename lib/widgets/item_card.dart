import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/freezer_compartment.dart';
import '../models/freezer_item.dart';

class FreezerItemCard extends StatelessWidget {
  final FreezerItem item;
  final bool showCompartmentBadge;
  final String? customCompartmentTitle;
  final List<FreezerCompartment>? availableCompartments;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemoveAll;
  final ValueChanged<String> onMoveCompartment;
  final VoidCallback? onToggleIcePack;

  const FreezerItemCard({
    super.key,
    required this.item,
    this.showCompartmentBadge = false,
    this.customCompartmentTitle,
    this.availableCompartments,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemoveAll,
    required this.onMoveCompartment,
    this.onToggleIcePack,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final compartment = FreezerCompartment.byId(item.compartmentId);
    final compTitle = customCompartmentTitle ?? compartment.title;
    final compartmentsList =
        availableCompartments ?? FreezerCompartment.siemensNoFrostCompartments;
    final freshness = item.freshnessStatus;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (item.category == FoodCategory.icePacks) {
      statusColor = item.isIcePackInUse ? Colors.orange.shade700 : Colors.blue.shade700;
      statusText = item.isIcePackInUse ? 'Unterwegs / In Benutzung' : 'Im Türfach (Einsatzbereit)';
      statusIcon = item.isIcePackInUse ? Icons.hiking : Icons.ac_unit;
    } else {
      switch (freshness) {
        case FreshnessStatus.fresh:
          statusColor = Colors.green.shade700;
          statusText = 'Frisch (${item.daysUntilExpiration} Tage übrig)';
          statusIcon = Icons.verified_outlined;
          break;
        case FreshnessStatus.expiringSoon:
          statusColor = Colors.orange.shade800;
          statusText = 'Bald verbrauchen (${item.daysUntilExpiration} Tage)';
          statusIcon = Icons.schedule;
          break;
        case FreshnessStatus.expired:
          statusColor = Colors.red.shade700;
          statusText = 'Gefrierbrand-Gefahr (${item.daysUntilExpiration.abs()} Tage überfällig)';
          statusIcon = Icons.warning_amber_rounded;
          break;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: freshness == FreshnessStatus.expired
              ? Colors.red.shade300
              : freshness == FreshnessStatus.expiringSoon
                  ? Colors.orange.shade300
                  : Colors.blueGrey.shade100,
          width: freshness == FreshnessStatus.fresh ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (showCompartmentBadge)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF005691).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                compTitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF005691),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.category.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(item.category.icon, size: 12, color: item.category.color),
                                const SizedBox(width: 4),
                                Text(
                                  item.category.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: item.category.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.imageUrl != null && item.imageUrl!.contains('r2.'))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'R2 Cloud',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.brand != null && item.brand!.isNotEmpty)
                        Text(
                          item.brand!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Eingefroren: ${dateFormatter.format(item.frozenAt)} von ${item.addedByName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '💡 ${item.notes}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.blueGrey.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.formattedQuantity,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF01579B),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.category == FoodCategory.icePacks && onToggleIcePack != null)
                  FilledButton.tonalIcon(
                    onPressed: onToggleIcePack,
                    icon: Icon(
                      item.isIcePackInUse ? Icons.login : Icons.logout,
                      size: 16,
                    ),
                    label: Text(
                      item.isIcePackInUse ? 'Zurück ins Türfach' : 'Kühlakku nutzen',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )
                else
                  Row(
                    children: [
                      _ActionButton(
                        icon: Icons.remove,
                        label: '-1',
                        color: Colors.orange.shade800,
                        onTap: onDecrement,
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.add,
                        label: '+1',
                        color: Colors.teal.shade700,
                        onTap: onIncrement,
                      ),
                    ],
                  ),
                Row(
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'In anderes Fach umräumen',
                      onSelected: onMoveCompartment,
                      itemBuilder: (context) {
                        return compartmentsList
                            .where((c) => c.id != item.compartmentId)
                            .map(
                              (c) => PopupMenuItem<String>(
                                value: c.id,
                                child: Row(
                                  children: [
                                    Icon(c.themeIcon, size: 18, color: c.accentColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('${c.slotBadge}: ${c.title}'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueGrey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.drive_file_move_outlined, size: 16),
                            SizedBox(width: 4),
                            Text('Umräumen', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.outbox_outlined,
                      label: 'Raus',
                      color: Colors.red.shade700,
                      onTap: onRemoveAll,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (item.thumbnailBase64 != null && item.thumbnailBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(item.thumbnailBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          item.imageUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildCategoryAvatar(),
        ),
      );
    }

    return _buildCategoryAvatar();
  }

  Widget _buildCategoryAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: item.category.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        item.category.icon,
        color: item.category.color,
        size: 28,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
