import 'package:flutter/material.dart';

enum FoodCategory {
  berriesAndFruit(
    id: 'berries_fruit',
    label: 'Beeren & Obst',
    icon: Icons.egg_alt_outlined,
    color: Color(0xFFD81B60),
    recommendedMonths: 10,
  ),
  vegetablesAndHerbs(
    id: 'vegetables',
    label: 'Gemüse & Kräuter',
    icon: Icons.eco_outlined,
    color: Color(0xFF2E7D32),
    recommendedMonths: 10,
  ),
  meatAndPoultry(
    id: 'meat',
    label: 'Fleisch & Geflügel',
    icon: Icons.restaurant_outlined,
    color: Color(0xFFC62828),
    recommendedMonths: 8,
  ),
  fishAndSeafood(
    id: 'fish',
    label: 'Fisch & Meeresfrüchte',
    icon: Icons.set_meal_outlined,
    color: Color(0xFF0277BD),
    recommendedMonths: 4,
  ),
  breadAndBakery(
    id: 'bread',
    label: 'Brot, Brötchen & Gebäck',
    icon: Icons.bakery_dining_outlined,
    color: Color(0xFFEF6C00),
    recommendedMonths: 3,
  ),
  cookedAndMeals(
    id: 'cooked',
    label: 'Vorgekochtes & Suppen',
    icon: Icons.soup_kitchen_outlined,
    color: Color(0xFF6A1B9A),
    recommendedMonths: 4,
  ),
  pizzaAndSnacks(
    id: 'pizza',
    label: 'Pizza & Backofen-Snacks',
    icon: Icons.local_pizza_outlined,
    color: Color(0xFFE65100),
    recommendedMonths: 6,
  ),
  iceCreamAndDessert(
    id: 'ice_cream',
    label: 'Eis & Desserts',
    icon: Icons.icecream_outlined,
    color: Color(0xFF00838F),
    recommendedMonths: 6,
  ),
  icePacks(
    id: 'ice_packs',
    label: 'Kühlakkus & Kühlelemente',
    icon: Icons.ac_unit_outlined,
    color: Color(0xFF1565C0),
    recommendedMonths: 60,
  ),
  other(
    id: 'other',
    label: 'Sonstiges Gefriergut',
    icon: Icons.kitchen_outlined,
    color: Color(0xFF455A64),
    recommendedMonths: 6,
  );

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final int recommendedMonths;

  const FoodCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.recommendedMonths,
  });

  static FoodCategory fromId(String? id) {
    return FoodCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => FoodCategory.other,
    );
  }
}

/// Frei wählbare thematische Beschriftung für jede einzelne Gefrierschrank-Schublade
class CompartmentCustomLabel {
  final String compartmentId;
  final String themeTitle;
  final String themeSubtitle;
  final String colorHex;
  final String iconKey;

  const CompartmentCustomLabel({
    required this.compartmentId,
    required this.themeTitle,
    required this.themeSubtitle,
    this.colorHex = '#005691',
    this.iconKey = 'snowflake',
  });

  Color get color {
    try {
      final clean = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF005691);
    }
  }

  IconData get icon => iconFromKey(iconKey);

  static IconData iconFromKey(String key) {
    switch (key) {
      case 'berries':
        return Icons.egg_alt_outlined;
      case 'vegetables':
        return Icons.eco_outlined;
      case 'meat':
        return Icons.restaurant_outlined;
      case 'fish':
        return Icons.set_meal_outlined;
      case 'bread':
        return Icons.bakery_dining_outlined;
      case 'cooked':
        return Icons.soup_kitchen_outlined;
      case 'pizza':
        return Icons.local_pizza_outlined;
      case 'icecream':
        return Icons.icecream_outlined;
      case 'herbs':
        return Icons.grass_outlined;
      case 'bigbox':
        return Icons.inventory_2_outlined;
      case 'snowflake':
      default:
        return Icons.ac_unit_rounded;
    }
  }

  Map<String, dynamic> toJson() => {
        'compartmentId': compartmentId,
        'themeTitle': themeTitle,
        'themeSubtitle': themeSubtitle,
        'colorHex': colorHex,
        'iconKey': iconKey,
      };

  factory CompartmentCustomLabel.fromJson(Map<String, dynamic> json) {
    return CompartmentCustomLabel(
      compartmentId: json['compartmentId']?.toString() ?? 'drawer_1',
      themeTitle: json['themeTitle']?.toString() ?? '',
      themeSubtitle: json['themeSubtitle']?.toString() ?? '',
      colorHex: json['colorHex']?.toString() ?? '#005691',
      iconKey: json['iconKey']?.toString() ?? 'snowflake',
    );
  }

  /// Vorlagen für schnelle thematische Sortierung einer Schublade
  static const List<Map<String, String>> thematicPresets = [
    {
      'title': 'Kräuter, Butter & Eiswürfel',
      'subtitle': 'Schnellzugriff beim Kochen',
      'colorHex': '#00897B',
      'iconKey': 'herbs',
    },
    {
      'title': 'Beeren, Obst & Smoothies',
      'subtitle': 'Heidelbeeren, Himbeeren, Frühstücks-Obst',
      'colorHex': '#D81B60',
      'iconKey': 'berries',
    },
    {
      'title': 'Vorgekochtes, Suppen & Dosen',
      'subtitle': 'Bolognese, Brühe, fertige Portionen',
      'colorHex': '#6A1B9A',
      'iconKey': 'cooked',
    },
    {
      'title': 'Gemüse & Beilagen',
      'subtitle': 'Spinat, Erbsen, Pfannengemüse, Pommes',
      'colorHex': '#2E7D32',
      'iconKey': 'vegetables',
    },
    {
      'title': 'Pizza, Braten & XXL-Boxen',
      'subtitle': 'Großes Gefriergut in der BigBox',
      'colorHex': '#E65100',
      'iconKey': 'pizza',
    },
    {
      'title': 'Fleisch, Geflügel & Grillgut',
      'subtitle': 'Steaks, Hackfleisch, Hähnchen, Würstchen',
      'colorHex': '#C62828',
      'iconKey': 'meat',
    },
    {
      'title': 'Fisch & Meeresfrüchte',
      'subtitle': 'Lachsfilet, Garnelen, Fischstäbchen',
      'colorHex': '#0277BD',
      'iconKey': 'fish',
    },
    {
      'title': 'Brot, Brötchen & Gebäck',
      'subtitle': 'Aufbackbrötchen, Brotscheiben, Kuchen',
      'colorHex': '#EF6C00',
      'iconKey': 'bread',
    },
    {
      'title': 'Eiscreme & Desserts',
      'subtitle': 'Eisbecher, Stieleis, Torten',
      'colorHex': '#00838F',
      'iconKey': 'icecream',
    },
  ];
}

class FreezerCompartment {
  final String id;
  final int positionNumber;
  final String slotBadge;
  final String title;
  final String subtitle;
  final String recommendation;
  final Color accentColor;
  final IconData themeIcon;
  final bool isBigBox;
  final bool isDoorCompartment;
  final double heightFactor;
  final int recommendedCapacityItems;
  final bool hasCustomLabel;

  const FreezerCompartment({
    required this.id,
    required this.positionNumber,
    required this.slotBadge,
    required this.title,
    required this.subtitle,
    required this.recommendation,
    this.accentColor = const Color(0xFF005691),
    this.themeIcon = Icons.ac_unit_rounded,
    this.isBigBox = false,
    this.isDoorCompartment = false,
    this.heightFactor = 1.0,
    this.recommendedCapacityItems = 12,
    this.hasCustomLabel = false,
  });

  /// Wendet eine benutzerdefinierte Schubladen-Beschriftung auf das Fach an
  FreezerCompartment withCustomLabel(CompartmentCustomLabel? custom) {
    if (custom == null || custom.themeTitle.trim().isEmpty) return this;
    return FreezerCompartment(
      id: id,
      positionNumber: positionNumber,
      slotBadge: slotBadge,
      title: custom.themeTitle.trim(),
      subtitle: custom.themeSubtitle.trim().isNotEmpty
          ? custom.themeSubtitle.trim()
          : subtitle,
      recommendation: recommendation,
      accentColor: custom.color,
      themeIcon: custom.icon,
      isBigBox: isBigBox,
      isDoorCompartment: isDoorCompartment,
      heightFactor: heightFactor,
      recommendedCapacityItems: recommendedCapacityItems,
      hasCustomLabel: true,
    );
  }

  /// Originalgetreue Struktur des Siemens NoFrost Gefrierschranks (6 Fächer + Türfach)
  static const List<FreezerCompartment> siemensNoFrostCompartments = [
    FreezerCompartment(
      id: 'drawer_1',
      positionNumber: 1,
      slotBadge: 'FACH 1 • OBEN',
      title: 'Kräuter & Schnellzugriff',
      subtitle: 'Oberes Fach unter dem NoFrost-Modul',
      recommendation: 'Kräuter, Butter, Eiswürfel, kleine Portionen',
      accentColor: Color(0xFF00897B),
      themeIcon: Icons.grass_outlined,
      heightFactor: 0.85,
      recommendedCapacityItems: 10,
    ),
    FreezerCompartment(
      id: 'drawer_2',
      positionNumber: 2,
      slotBadge: 'FACH 2',
      title: 'Beeren & Obst',
      subtitle: 'Schublade 2 (Oben-Mitte)',
      recommendation: 'Kultur-Heidelbeeren, Beerenmischung, Obst, flache Beutel',
      accentColor: Color(0xFFD81B60),
      themeIcon: Icons.egg_alt_outlined,
      heightFactor: 1.0,
      recommendedCapacityItems: 12,
    ),
    FreezerCompartment(
      id: 'drawer_3',
      positionNumber: 3,
      slotBadge: 'FACH 3',
      title: 'Gemüse & Vorgekochtes',
      subtitle: 'Schublade 3 (Mitte)',
      recommendation: 'Gemüse, Brühe, Pfannengerichte, Vorratsdosen',
      accentColor: Color(0xFF2E7D32),
      themeIcon: Icons.soup_kitchen_outlined,
      heightFactor: 1.0,
      recommendedCapacityItems: 14,
    ),
    FreezerCompartment(
      id: 'big_box',
      positionNumber: 4,
      slotBadge: 'FACH 4 • BIGBOX XXL',
      title: 'BigBox • Großpackungen & Pizza',
      subtitle: 'Extra hohe XXL-Großraum-Schublade',
      recommendation: 'Großes Gefriergut, Braten, Pizza-Kartons, hohe Boxen',
      accentColor: Color(0xFF005691),
      themeIcon: Icons.inventory_2_outlined,
      isBigBox: true,
      heightFactor: 1.45,
      recommendedCapacityItems: 20,
    ),
    FreezerCompartment(
      id: 'drawer_5',
      positionNumber: 5,
      slotBadge: 'FACH 5',
      title: 'Fleisch, Fisch & Backwaren',
      subtitle: 'Schublade 5 (Unten-Mitte)',
      recommendation: 'Fleisch, Geflügel, Fisch, Brot & Brötchen',
      accentColor: Color(0xFFC62828),
      themeIcon: Icons.restaurant_outlined,
      heightFactor: 1.0,
      recommendedCapacityItems: 12,
    ),
    FreezerCompartment(
      id: 'drawer_6',
      positionNumber: 6,
      slotBadge: 'FACH 6 • UNTEN',
      title: 'Langzeit-Vorrat & Eis',
      subtitle: 'Untere Vorrats-Schublade',
      recommendation: 'Langzeit-Vorrat, Eingekochtes, Eiscreme',
      accentColor: Color(0xFF00838F),
      themeIcon: Icons.icecream_outlined,
      heightFactor: 0.9,
      recommendedCapacityItems: 10,
    ),
    FreezerCompartment(
      id: 'door_icepacks',
      positionNumber: 7,
      slotBadge: 'TÜRFACH',
      title: 'Tür-Kühlakku-Halter',
      subtitle: 'Integriertes Halterfach in der Gefrierschranktür',
      recommendation: 'Kühlakkus & Kühlelemente (Im Schrank / Unterwegs)',
      accentColor: Color(0xFF1565C0),
      themeIcon: Icons.ac_unit_rounded,
      isDoorCompartment: true,
      heightFactor: 0.85,
      recommendedCapacityItems: 6,
    ),
  ];

  static FreezerCompartment byId(
    String id, [
    Map<String, CompartmentCustomLabel>? customLabels,
  ]) {
    final base = siemensNoFrostCompartments.firstWhere(
      (c) => c.id == id,
      orElse: () => siemensNoFrostCompartments.first,
    );
    if (customLabels != null && customLabels.containsKey(id)) {
      return base.withCustomLabel(customLabels[id]);
    }
    return base;
  }

  static List<FreezerCompartment> resolvedCompartments([
    Map<String, CompartmentCustomLabel>? customLabels,
  ]) {
    return siemensNoFrostCompartments
        .map((c) => c.withCustomLabel(customLabels?[c.id]))
        .toList();
  }
}
