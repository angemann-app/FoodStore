import 'package:flutter/material.dart';

import '../models/freezer_compartment.dart';
import '../models/freezer_item.dart';
import '../services/app_state.dart';
import '../widgets/compartment_label_dialog.dart';
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
    final isFiltering =
        query.isNotEmpty || _onlyShowExpiring || _selectedCategory != null;
    final expiringItems = appState.expiringOrExpiredItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 98),
      children: [
        // 1. Edles Siemens iQ500 / Home Connect Cockpit & Status-Dashboard
        _buildSiemensCockpit(appState, expiringItems.length),
        const SizedBox(height: 14),

        // 2. Moderne Glas-Suchleiste & Schnellfilter
        _buildSearchAndFilterBar(expiringItems.length),
        const SizedBox(height: 14),

        // 3. Gefrierschrank-3D-Schubladen-Ansicht oder Suchergebnisse
        if (isFiltering)
          _buildFilteredItemsList(appState)
        else
          _buildRealisticSiemensFreezer(context, appState),
      ],
    );
  }

  Widget _buildSiemensCockpit(AppState appState, int warningCount) {
    final connectedRelays = appState.nostrService.connectedCount;
    final totalRelays = appState.household.relays.length;
    final totalItems = appState.items.length;
    final totalPieces = appState.items.fold<double>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B192C),
            Color(0xFF132A46),
            Color(0xFF004B7C),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00335A).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Obere originalgetreue SIEMENS Blende mit LED-Digitalanzeige
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SIEMENS',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'iQ500 • noFrost superFreezing',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: Colors.cyanAccent.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Beleuchtetes -18°C Digital-Panel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060D17),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.ac_unit_rounded,
                        size: 16,
                        color: Color(0xFF00E5FF),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '-18 °C',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00E5FF),
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ECO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3 kompakte Kennzahlen-Karten im Glas-Look
            Row(
              children: [
                Expanded(
                  child: _buildCockpitMetric(
                    icon: Icons.inventory_2_outlined,
                    value: '$totalItems Pos.',
                    label: '${totalPieces.toInt()} Einheiten gesamt',
                    accent: const Color(0xFF4FC3F7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCockpitMetric(
                    icon: warningCount > 0
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    value: warningCount > 0 ? '$warningCount Warnung' : '100% Frisch',
                    label: warningCount > 0
                        ? 'Bald verbrauchen'
                        : 'Kein Gefrierbrand',
                    accent: warningCount > 0
                        ? const Color(0xFFFFB74D)
                        : const Color(0xFF69F0AE),
                    onTap: warningCount > 0
                        ? () => setState(() => _onlyShowExpiring = !_onlyShowExpiring)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCockpitMetric(
                    icon: Icons.hub_outlined,
                    value: '$connectedRelays/$totalRelays Relays',
                    label: '${appState.household.activeMembers.length} Mitgl. (${appState.household.adminCount}/2 Admins)',
                    accent: connectedRelays > 0
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFFFFCC80),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCockpitMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(int warningCount) {
    final query = _searchCtrl.text.trim();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withValues(alpha: 0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Gefriergut oder Schubladen-Thema suchen…',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.blueGrey.shade400),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF005691)),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.blueGrey.shade100),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.blueGrey.shade100),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: _onlyShowExpiring,
              selectedColor: Colors.orange.shade100,
              backgroundColor: Colors.white,
              avatar: Icon(
                Icons.schedule_rounded,
                size: 17,
                color: warningCount > 0 ? Colors.deepOrange : Colors.blueGrey,
              ),
              label: Text(
                'Ablauf ($warningCount)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onSelected: (val) => setState(() => _onlyShowExpiring = val),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  avatar: const Icon(Icons.kitchen, size: 15),
                  label: const Text('Schrank-Ansicht (6 Fächer + Tür)', style: TextStyle(fontSize: 12)),
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
      ],
    );
  }

  Widget _buildRealisticSiemensFreezer(BuildContext context, AppState appState) {
    final compartments = appState.resolvedCompartments;
    final mainDrawers = compartments.where((c) => !c.isDoorCompartment).toList();
    final doorCompartment = compartments.firstWhere((c) => c.isDoorCompartment);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info-Banner zum individuellen Beschriften der Schubladen
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: Row(
            children: [
              const Icon(Icons.label_important_outline, size: 18, color: Color(0xFF005691)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tipp: Tippe auf das Etikett-Symbol 🏷️ einer Schublade, um sie thematisch zu beschriften (z. B. "Beeren & Obst", "Grillgut").',
                  style: TextStyle(fontSize: 12, color: Color(0xFF01579B)),
                ),
              ),
            ],
          ),
        ),

        // Äußerer Siemens Gefrierschrank-Korpus mit gebürstetem Metallrahmen & Innenraum-Frost-Effekt
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFDCE5EC),
                Color(0xFFEDF3F8),
                Color(0xFFD5E0E8),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFB0BEC5), width: 3.5),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Decken-LED-Kaltlicht (wie auf dem Foto oben im geöffneten Schrank)
              Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 42, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF80D8FF),
                      Colors.white,
                      Color(0xFF80D8FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.65),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Alle 6 Schubladen (inkl. BigBox XXL in Position 4)
              ...mainDrawers.map(
                (comp) => _buildFrostedGlassDrawer(context, appState, comp),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Türfach für Kühlakkus (im Tür-Rahmen-Design)
        _buildFrostedGlassDrawer(context, appState, doorCompartment),
      ],
    );
  }

  Widget _buildFrostedGlassDrawer(
    BuildContext context,
    AppState appState,
    FreezerCompartment compartment,
  ) {
    final items = appState.itemsInCompartment(compartment.id);
    final hasExpired = items.any((i) => i.freshnessStatus == FreshnessStatus.expired);
    final hasExpiringSoon =
        items.any((i) => i.freshnessStatus == FreshnessStatus.expiringSoon);
    final fillRatio =
        (items.length / compartment.recommendedCapacityItems).clamp(0.0, 1.0);
    final themeColor = compartment.accentColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
            minHeight: compartment.isBigBox ? 148 : 106,
          ),
          decoration: BoxDecoration(
            // Durchscheinende Acrylglas-Schubladenfront mit leichtem Frost-Verlauf
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: compartment.isBigBox
                  ? [
                      const Color(0xFFFFFFFF),
                      const Color(0xFFEAF6FF),
                      themeColor.withValues(alpha: 0.08),
                    ]
                  : [
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF5FAFD),
                      themeColor.withValues(alpha: 0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasExpired
                  ? Colors.red.shade400
                  : hasExpiringSoon
                      ? Colors.orange.shade400
                      : themeColor.withValues(alpha: compartment.isBigBox ? 0.55 : 0.35),
              width: compartment.isBigBox ? 2.2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Gebürstete Edelstahl-Griffleiste + farbiges Themen-Etikett
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFECEFF1),
                      Color(0xFFCFD8DC),
                      Color(0xFFE4E9ED),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.blueGrey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Aufgestecktes farbiges Themen-Etikett (wie ein echtes Schildchen an der Schublade)
                    InkWell(
                      onTap: () => CompartmentLabelDialog.show(
                        context,
                        appState: appState,
                        compartment: compartment,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeColor,
                              themeColor.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              compartment.themeIcon,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  compartment.slotBadge,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                                Text(
                                  compartment.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Warn-Badge bei Gefrierbrand / Ablauf
                    if (hasExpired || hasExpiringSoon)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasExpired ? Colors.red.shade600 : Colors.orange.shade800,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              hasExpired ? 'Gefrierbrand' : 'Bald fällig',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Schnell-Einlagern-Button ("+ Rein") direkt an der Schublade
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
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_outline, size: 14, color: themeColor),
                            const SizedBox(width: 4),
                            Text(
                              'Rein',
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 11,
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

              // 2. Schubladen-Innenraum (Acrylglas-Sichtfenster mit Wasserzeichen & Artikeln)
              Stack(
                children: [
                  if (compartment.isBigBox)
                    Positioned(
                      right: 14,
                      bottom: 8,
                      child: Text(
                        'bigBox',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: themeColor.withValues(alpha: 0.07),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                compartment.subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade600,
                                ),
                              ),
                            ),
                            Text(
                              '${items.length} / ${compartment.recommendedCapacityItems} Plätze',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (items.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blueGrey.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.ac_unit,
                                  size: 15,
                                  color: Colors.blueGrey.shade300,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Schublade frei • Ideal für: ${compartment.recommendation}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.blueGrey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: items.map((item) {
                              final freshness = item.freshnessStatus;
                              final dotColor = item.isIcePackInUse
                                  ? Colors.orange
                                  : freshness == FreshnessStatus.expired
                                      ? Colors.red
                                      : freshness == FreshnessStatus.expiringSoon
                                          ? Colors.orange
                                          : Colors.green;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: item.category.color.withValues(alpha: 0.35),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: dotColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      item.category.icon,
                                      size: 14,
                                      color: item.category.color,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        item.formattedQuantity,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: themeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 10),
                        // Elegante Füllstands-Anzeige in der Themenfarbe der Schublade
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: fillRatio,
                            minHeight: 5,
                            backgroundColor: themeColor.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              fillRatio > 0.88 ? Colors.deepOrange : themeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(Icons.search_off, size: 46, color: Colors.blueGrey),
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
              customCompartmentTitle:
                  appState.compartmentById(item.compartmentId).title,
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
