import 'package:flutter/material.dart';

enum FoodCategory {
  berriesAndFruit(
    id: 'berries_fruit',
    label: 'Beeren & Obst',
    icon: Icons.egg_alt_outlined,
    color: Color(0xFFE91E63),
    recommendedMonths: 10,
  ),
  vegetablesAndHerbs(
    id: 'vegetables',
    label: 'Gemüse & Kräuter',
    icon: Icons.eco_outlined,
    color: Color(0xFF4CAF50),
    recommendedMonths: 10,
  ),
  meatAndPoultry(
    id: 'meat',
    label: 'Fleisch & Geflügel',
    icon: Icons.restaurant_outlined,
    color: Color(0xFFD32F2F),
    recommendedMonths: 8,
  ),
  fishAndSeafood(
    id: 'fish',
    label: 'Fisch & Meeresfrüchte',
    icon: Icons.set_meal_outlined,
    color: Color(0xFF0288D1),
    recommendedMonths: 4,
  ),
  breadAndBakery(
    id: 'bread',
    label: 'Brot, Brötchen & Gebäck',
    icon: Icons.bakery_dining_outlined,
    color: Color(0xFFFF8F00),
    recommendedMonths: 3,
  ),
  cookedAndMeals(
    id: 'cooked',
    label: 'Selbstgekochtes & Fertiggerichte',
    icon: Icons.soup_kitchen_outlined,
    color: Color(0xFF7B1FA2),
    recommendedMonths: 4,
  ),
  pizzaAndSnacks(
    id: 'pizza',
    label: 'Pizza & Backofen-Snacks',
    icon: Icons.local_pizza_outlined,
    color: Color(0xFFF57C00),
    recommendedMonths: 6,
  ),
  iceCreamAndDessert(
    id: 'ice_cream',
    label: 'Eis & Desserts',
    icon: Icons.icecream_outlined,
    color: Color(0xFF00ACC1),
    recommendedMonths: 6,
  ),
  icePacks(
    id: 'ice_packs',
    label: 'Kühlakkus & Kühlelemente',
    icon: Icons.ac_unit_outlined,
    color: Color(0xFF1976D2),
    recommendedMonths: 60,
  ),
  other(
    id: 'other',
    label: 'Sonstiges Gefriergut',
    icon: Icons.kitchen_outlined,
    color: Color(0xFF607D8B),
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

class FreezerCompartment {
  final String id;
  final int positionNumber;
  final String title;
  final String subtitle;
  final String recommendation;
  final bool isBigBox;
  final bool isDoorCompartment;
  final double heightFactor;
  final int recommendedCapacityItems;

  const FreezerCompartment({
    required this.id,
    required this.positionNumber,
    required this.title,
    required this.subtitle,
    required this.recommendation,
    this.isBigBox = false,
    this.isDoorCompartment = false,
    this.heightFactor = 1.0,
    this.recommendedCapacityItems = 12,
  });

  /// Originalgetreue Struktur des Siemens NoFrost Gefrierschranks (6 Fächer + Türfach)
  static const List<FreezerCompartment> siemensNoFrostCompartments = [
    FreezerCompartment(
      id: 'drawer_1',
      positionNumber: 1,
      title: 'Fach 1 (Oben)',
      subtitle: 'Oberes Schnellzugriff-Fach',
      recommendation: 'Kräuter, Butter, Eiswürfel, kleine Portionen',
      heightFactor: 0.85,
      recommendedCapacityItems: 10,
    ),
    FreezerCompartment(
      id: 'drawer_2',
      positionNumber: 2,
      title: 'Fach 2',
      subtitle: 'Schublade 2 (Oben-Mitte)',
      recommendation: 'Beeren (z. B. Kultur-Heidelbeeren), Obst, flache Beutel',
      heightFactor: 1.0,
      recommendedCapacityItems: 12,
    ),
    FreezerCompartment(
      id: 'drawer_3',
      positionNumber: 3,
      title: 'Fach 3',
      subtitle: 'Schublade 3 (Mitte)',
      recommendation: 'Gemüse, Beilagen, Pfannengerichte, Dosen',
      heightFactor: 1.0,
      recommendedCapacityItems: 14,
    ),
    FreezerCompartment(
      id: 'big_box',
      positionNumber: 4,
      title: 'Fach 4 • BigBox XXL',
      subtitle: 'Extra hohe Großraum-Schublade',
      recommendation: 'Großes Gefriergut, Braten, Pizza-Kartons, Vorratsboxen',
      isBigBox: true,
      heightFactor: 1.45,
      recommendedCapacityItems: 20,
    ),
    FreezerCompartment(
      id: 'drawer_5',
      positionNumber: 5,
      title: 'Fach 5',
      subtitle: 'Schublade 5 (Unten-Mitte)',
      recommendation: 'Fleisch, Geflügel, Fisch, Brot & Brötchen',
      heightFactor: 1.0,
      recommendedCapacityItems: 12,
    ),
    FreezerCompartment(
      id: 'drawer_6',
      positionNumber: 6,
      title: 'Fach 6 (Unten)',
      subtitle: 'Untere Vorrats-Schublade',
      recommendation: 'Langzeit-Vorrat, Eingekochtes, Eiscreme',
      heightFactor: 0.9,
      recommendedCapacityItems: 10,
    ),
    FreezerCompartment(
      id: 'door_icepacks',
      positionNumber: 7,
      title: 'Türfach (Kühlakkus)',
      subtitle: 'Integrierter Tür-Kühlakku-Halter',
      recommendation: 'Kühlakkus & Kühlelemente (Im Schrank / Unterwegs)',
      isDoorCompartment: true,
      heightFactor: 0.85,
      recommendedCapacityItems: 6,
    ),
  ];

  static FreezerCompartment byId(String id) {
    return siemensNoFrostCompartments.firstWhere(
      (c) => c.id == id,
      orElse: () => siemensNoFrostCompartments.first,
    );
  }
}
