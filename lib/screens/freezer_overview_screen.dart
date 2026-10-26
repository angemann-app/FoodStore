import 'package:flutter/material.dart';

import '../models/freezer_compartment.dart';
import '../models/freezer_item.dart';
import '../services/app_state.dart';
import '../widgets/compartment_label_dialog.dart';
import '../widgets/eiszeit_visual_effects.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 98),
      children: [
        // 1. Aufwändiges 3D "Eiszeit" Hero-Cockpit mit Mammut-Banner, Schneeflocken & Neon-Tachos
        _buildEiszeitHeroCockpit(appState, expiringItems.length),
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

  Widget _buildEiszeitHeroCockpit(AppState appState, int warningCount) {
    final connectedRelays = appState.nostrService.connectedCount;
    final totalRelays = appState.household.relays.length;
    final totalItems = appState.items.length;
    final totalCapacity = appState.resolvedCompartments.fold<int>(
      0,
      (sum, c) => sum + c.recommendedCapacityItems,
    );
    final capacityRatio =
        totalCapacity > 0 ? (totalItems / totalCapacity).clamp(0.0, 1.0) : 0.0;
    final freshCount = (totalItems - warningCount).clamp(0, totalItems);
    final freshRatio = totalItems > 0 ? freshCount / totalItems : 1.0;
    final relayRatio = totalRelays > 0 ? connectedRelays / totalRelays : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AnimatedFrostBackground(
        particleCount: 22,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF002B49).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 3D Eiszeit-Höhlen & Mammut Hero-Grafik im Hintergrund
              Positioned.fill(
                child: Image.asset(
                  'assets/images/eiszeit_hero_banner.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              // Abdunkelnder Arktis-Glas-Verlauf für perfekte Lesbarkeit
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF061527).withValues(alpha: 0.72),
                        const Color(0xFF08203A).withValues(alpha: 0.58),
                        const Color(0xFF051322).withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Obere SIEMENS iQ500 Blende mit beleuchtetem -18°C LED-Panel
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/eiszeit_app_icon.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SIEMENS • EISZEIT',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'iQ500 noFrost • Frosti Bestandswächter',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.cyanAccent.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Digitales -18°C SuperFreezing Display
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF040B14).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                                blurRadius: 12,
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
                              const SizedBox(width: 5),
                              const Text(
                                '-18 °C',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF00E5FF),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SUPER',
                                  style: TextStyle(
                                    fontSize: 8.5,
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
                    const SizedBox(height: 18),

                    // 3 Runde Neon-Eis-Tachos (CircularFrostGauge)
                    Row(
                      children: [
                        Expanded(
                          child: CircularFrostGauge(
                            progress: capacityRatio,
                            centerValue: '$totalItems Pos.',
                            bottomLabel: 'Auslastung (${(capacityRatio * 100).round()}%)',
                            color: const Color(0xFF00E5FF),
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CircularFrostGauge(
                            progress: freshRatio,
                            centerValue: '${(freshRatio * 100).round()}%',
                            bottomLabel: warningCount > 0
                                ? '$warningCount Ablauf-Warnung'
                                : 'Frische-Garantie',
                            color: warningCount > 0
                                ? const Color(0xFFFFB74D)
                                : const Color(0xFF69F0AE),
                            icon: warningCount > 0
                                ? Icons.warning_amber_rounded
                                : Icons.verified_outlined,
                            onTap: warningCount > 0
                                ? () => setState(() => _onlyShowExpiring = !_onlyShowExpiring)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CircularFrostGauge(
                            progress: relayRatio > 0 ? relayRatio : 0.35,
                            centerValue: '$connectedRelays/$totalRelays',
                            bottomLabel:
                                '${appState.household.activeMembers.length} Mitgl. (${appState.household.adminCount}/2 Admins)',
                            color: connectedRelays > 0
                                ? const Color(0xFF69F0AE)
                                : const Color(0xFF80D8FF),
                            icon: Icons.bolt_rounded,
                          ),
                        ),
                      ],
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
                      color: Colors.blueGrey.withValues(alpha: 0.08),
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
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE1F5FE), Color(0xFFFFFFFF)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF81D4FA)),
          ),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/eiszeit_app_icon.jpg',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Thematische Ordnung: Tippe auf ein farbiges Schubladen-Etikett 🏷️, um Namen, Symbol & Farbe frei anzupassen!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF01579B),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Äußerer Siemens Gefrierschrank-Korpus mit gebürstetem Metallrahmen, Eiszapfen & Innenraum-Frost-Effekt
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFCFDCE6),
                Color(0xFFE8F1F7),
                Color(0xFFC7D6E2),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF90A4AE), width: 4.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D2745).withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                // Glitzernde Eiszapfen oben an der Schrankdecke
                const IcicleRow(height: 16, color: Color(0xFF80D8FF)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
                  child: Column(
                    children: [
                      // Decken-LED-Kaltlicht (wie auf dem Foto oben im geöffneten Schrank)
                      Container(
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 46, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF40C4FF),
                              Colors.white,
                              Color(0xFF40C4FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.75),
                              blurRadius: 18,
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
              ],
            ),
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
        borderRadius: BorderRadius.circular(20),
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
            minHeight: compartment.isBigBox ? 154 : 112,
          ),
          decoration: BoxDecoration(
            // Durchscheinende Acrylglas-Schubladenfront mit 3D-Frost-Verlauf
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: compartment.isBigBox
                  ? [
                      const Color(0xFFFFFFFF),
                      const Color(0xFFE3F4FF),
                      themeColor.withValues(alpha: 0.11),
                    ]
                  : [
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF2F8FC),
                      themeColor.withValues(alpha: 0.06),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasExpired
                  ? Colors.red.shade400
                  : hasExpiringSoon
                      ? Colors.orange.shade400
                      : themeColor.withValues(alpha: compartment.isBigBox ? 0.6 : 0.4),
              width: compartment.isBigBox ? 2.4 : 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Gebürstete 3D-Edelstahl-Griffleiste + aufgestecktes Themen-Etikett mit Metall-Öse
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF5F7F9),
                      Color(0xFFCFD8DC),
                      Color(0xFFECEFF1),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.blueGrey.shade200,
                      width: 1.2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Aufgestecktes farbiges Themen-Etikett (mit Metall-Öse links wie ein echtes Schild)
                    Flexible(
                      child: InkWell(
                        onTap: () => CompartmentLabelDialog.show(
                          context,
                          appState: appState,
                          compartment: compartment,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                themeColor,
                                themeColor.withValues(alpha: 0.84),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: themeColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Kleine silberne Etikett-Niete
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFECEFF1),
                                  border: Border.all(
                                    color: Colors.black38,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Icon(
                                compartment.themeIcon,
                                size: 17,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      compartment.slotBadge,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                    Text(
                                      compartment.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
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
                    ),
                    const SizedBox(width: 8),

                    // Warn-Badge bei Gefrierbrand / Ablauf
                    if (hasExpired || hasExpiringSoon)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: themeColor.withValues(alpha: 0.45)),
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

              // 2. Schubladen-Innenraum (Acrylglas-Sichtfenster mit Wasserzeichen & 3D-Eisblock-Artikeln)
              Stack(
                children: [
                  if (compartment.isBigBox)
                    Positioned(
                      right: 14,
                      bottom: 8,
                      child: Text(
                        'bigBox XXL',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: themeColor.withValues(alpha: 0.08),
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
                            spacing: 7,
                            runSpacing: 7,
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
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      const Color(0xFFF0F9FF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: item.category.color.withValues(alpha: 0.4),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: item.category.color.withValues(alpha: 0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: dotColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      item.category.icon,
                                      size: 15,
                                      color: item.category.color,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(6),
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
                            minHeight: 5.5,
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
              availableCompartments: appState.resolvedCompartments,
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
