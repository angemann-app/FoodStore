import 'package:flutter/material.dart';

import '../models/freezer_compartment.dart';
import '../models/freezer_item.dart';
import '../services/app_state.dart';
import '../widgets/item_card.dart';
import 'add_item_sheet.dart';
import 'compartment_detail_screen.dart';

class FreezerOverviewScreen extends StatefulWidget {
  final AppState appState;

  const FreezerOverviewScreen({
    super.key,
    required this.appState,
  });

  @override
  State<FreezerOverviewScreen> createState() => _FreezerOverviewScreenState();
}

class _FreezerOverviewScreenState extends State<FreezerOverviewScreen> {
  final _searchCtrl = TextEditingController();
  bool _onlyShowExpiring = false;
  FoodCategory? _selectedCategory;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final query = _searchCtrl.text.trim();
    final isFiltering = query.isNotEmpty || _onlyShowExpiring || _selectedCategory != null;
    final expiringItems = appState.expiringOrExpiredItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
      children: [
        // Originalgetreue SIEMENS NoFrost -18°C Kopfzeile (wie am echten Schrank)
        _buildSiemensHeaderBar(appState, expiringItems.length),
        const SizedBox(height: 14),

        // Suchleiste & Schnellfilter
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Gefriergut suchen (z. B. Heidelbeeren, Pizza, Fach…)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.blueGrey.shade100),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: _onlyShowExpiring,
              selectedColor: Colors.orange.shade100,
              avatar: Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: expiringItems.isNotEmpty ? Colors.orange.shade900 : Colors.blueGrey,
              ),
              label: Text(
                'Ablauf (${expiringItems.length})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              onSelected: (val) => setState(() => _onlyShowExpiring = val),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Kategorie-Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Alle Fächer (Schrank-Ansicht)', style: TextStyle(fontSize: 12)),
                  selected: _selectedCategory == null && !_onlyShowExpiring && query.isEmpty,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = null;
                      _onlyShowExpiring = false;
                      _searchCtrl.clear();
                    });
                  },
                ),
              ),
              ...FoodCategory.values.map((cat) {
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Icon(cat.icon, size: 15, color: selected ? Colors.white : cat.color),
                    label: Text(cat.label, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    selectedColor: cat.color,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() => _selectedCategory = val ? cat : null);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (isFiltering)
          _buildFilteredItemsList(appState)
        else
          _buildSiemensFreezerVisual(context, appState),
      ],
    );
  }

  Widget _buildSiemensHeaderBar(AppState appState, int warningCount) {
    final connectedRelays = appState.nostrService.connectedCount;
    final totalRelays = appState.household.relays.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIEMENS',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  color: Color(0xFF005691),
                ),
              ),
              // Schwarzes LED-Temperaturpanel mit -18°C Anzeige wie auf dem Foto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.ac_unit, size: 13, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 6),
                    const Text(
                      '-18 °C',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connectedRelays > 0 ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'noFrost',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF455A64),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF005691)),
                  const SizedBox(width: 4),
                  Text(
                    '${appState.items.length} Positionen eingelagert',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    connectedRelays > 0 ? Icons.bolt : Icons.cloud_queue,
                    size: 15,
                    color: connectedRelays > 0 ? Colors.teal.shade700 : Colors.blueGrey,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Nostr: $connectedRelays/$totalRelays Relays • ${appState.household.activeMembers.length} Mitgl. (${appState.household.adminCount}/2 Admins)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSiemensFreezerVisual(BuildContext context, AppState appState) {
    final mainDrawers = FreezerCompartment.siemensNoFrostCompartments
        .where((c) => !c.isDoorCompartment)
        .toList();
    final doorCompartment = FreezerCompartment.siemensNoFrostCompartments
        .firstWhere((c) => c.isDoorCompartment);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Gefrierschrank-Gehäuse mit 6 Schubladen (inkl. BigBox XXL)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFCFD8DC), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Obere LED-Innenbeleuchtung
              Container(
                height: 8,
                width: 140,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB3E5FC), Colors.white, Color(0xFFB3E5FC)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              ...mainDrawers.map(
                (comp) => _buildDrawerWidget(context, appState, comp),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Türfach für Kühlakkus (wie auf dem Foto rechts in der offenen Tür)
        _buildDrawerWidget(context, appState, doorCompartment),
      ],
    );
  }

  Widget _buildDrawerWidget(
    BuildContext context,
    AppState appState,
    FreezerCompartment compartment,
  ) {
    final items = appState.itemsInCompartment(compartment.id);
    final hasExpired = items.any((i) => i.freshnessStatus == FreshnessStatus.expired);
    final hasExpiringSoon = items.any((i) => i.freshnessStatus == FreshnessStatus.expiringSoon);
    final fillRatio = (items.length / compartment.recommendedCapacityItems).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CompartmentDetailScreen(
                appState: appState,
                compartment: compartment,
              ),
            ),
          );
        },
        child: Container(
          constraints: BoxConstraints(
            minHeight: compartment.isBigBox ? 128 : 94,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: compartment.isDoorCompartment
                  ? [const Color(0xFFE3F2FD), const Color(0xFFFFFFFF)]
                  : compartment.isBigBox
                      ? [const Color(0xFFF5FAFF), const Color(0xFFE1F5FE)]
                      : [const Color(0xFFFFFFFF), const Color(0xFFF2F7FB)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasExpired
                  ? Colors.red.shade400
                  : hasExpiringSoon
                      ? Colors.orange.shade400
                      : compartment.isBigBox
                          ? const Color(0xFF0288D1)
                          : const Color(0xFFB0BEC5),
              width: compartment.isBigBox ? 2.0 : 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Silberne Siemens-Griffleiste oben an jeder Schublade
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: compartment.isBigBox
                        ? [const Color(0xFF005691), const Color(0xFF0277BD)]
                        : [const Color(0xFFCFD8DC), const Color(0xFFECEFF1)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(
                      compartment.isDoorCompartment
                          ? Icons.ac_unit
                          : compartment.isBigBox
                              ? Icons.all_inbox_rounded
                              : Icons.dns_outlined,
                      size: 16,
                      color: compartment.isBigBox ? Colors.white : const Color(0xFF37474F),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        compartment.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: compartment.isBigBox ? Colors.white : const Color(0xFF263238),
                        ),
                      ),
                    ),
                    if (hasExpired || hasExpiringSoon)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasExpired ? Colors.red.shade600 : Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasExpired ? 'Gefrierbrand!' : 'Bald verbrauchen',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: compartment.isBigBox
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${items.length} Pos.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: compartment.isBigBox ? Colors.white : const Color(0xFF005691),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF005691),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 13, color: Colors.white),
                            Text(
                              'Rein',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Inhalt der transparenten Gefrierschublade
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (items.isEmpty)
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.blueGrey.shade400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Leer • Ideal für: ${compartment.recommendation}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: items.map((item) {
                          final isWarn = item.freshnessStatus != FreshnessStatus.fresh;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.isIcePackInUse
                                  ? Colors.orange.shade50
                                  : isWarn
                                      ? Colors.amber.shade50
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: item.isIcePackInUse
                                    ? Colors.orange.shade300
                                    : isWarn
                                        ? Colors.orange.shade400
                                        : item.category.color.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(item.category.icon, size: 14, color: item.category.color),
                                const SizedBox(width: 5),
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '(${item.formattedQuantity})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fillRatio,
                        minHeight: 4,
                        backgroundColor: Colors.blueGrey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          fillRatio > 0.85 ? Colors.orange : const Color(0xFF0288D1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredItemsList(AppState appState) {
    List<FreezerItem> results = appState.searchItems(
      _searchCtrl.text,
      categoryFilter: _selectedCategory,
    );
    if (_onlyShowExpiring) {
      results = results
          .where((i) => i.freshnessStatus != FreshnessStatus.fresh)
          .toList();
    }

    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.search_off, size: 44, color: Colors.blueGrey),
            SizedBox(height: 8),
            Text(
              'Keine passenden Artikel im Gefrierschrank gefunden.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Column(
      children: results
          .map(
            (item) => FreezerItemCard(
              item: item,
              showCompartmentBadge: true,
              onIncrement: () => appState.adjustItemQuantity(item, 1),
              onDecrement: () => appState.adjustItemQuantity(item, -1),
              onRemoveAll: () => appState.adjustItemQuantity(
                item,
                -item.quantity,
                note: 'Komplett entnommen',
              ),
              onMoveCompartment: (targetId) =>
                  appState.moveItemToCompartment(item, targetId),
              onToggleIcePack: () => appState.toggleIcePackInUse(item),
            ),
          )
          .toList(),
    );
  }
}
