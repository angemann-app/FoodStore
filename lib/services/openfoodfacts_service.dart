import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/freezer_compartment.dart';

class BarcodeProductResult {
  final String barcode;
  final String name;
  final String? brand;
  final FoodCategory suggestedCategory;
  final String? imageUrl;
  final String? quantityHint;

  const BarcodeProductResult({
    required this.barcode,
    required this.name,
    this.brand,
    required this.suggestedCategory,
    this.imageUrl,
    this.quantityHint,
  });
}

class OpenFoodFactsService {
  static Future<BarcodeProductResult?> lookupBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$cleanCode.json'
        '?fields=product_name,product_name_de,brands,categories_tags,image_front_small_url,quantity',
      );
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Eiszeit-Freezer-App/1.0 (https://github.com/angemann-app/FoodStore)',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1 || data['product'] is! Map<String, dynamic>) {
        return null;
      }

      final product = data['product'] as Map<String, dynamic>;
      final nameDe = product['product_name_de']?.toString().trim() ?? '';
      final nameGeneric = product['product_name']?.toString().trim() ?? '';
      final name = nameDe.isNotEmpty ? nameDe : nameGeneric;
      if (name.isEmpty) return null;

      final brand = product['brands']?.toString().split(',').first.trim();
      final imageUrl = product['image_front_small_url']?.toString().trim();
      final quantityHint = product['quantity']?.toString().trim();
      final tags = (product['categories_tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();

      return BarcodeProductResult(
        barcode: cleanCode,
        name: name,
        brand: (brand != null && brand.isNotEmpty) ? brand : null,
        suggestedCategory: _inferCategory(name, tags),
        imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
        quantityHint: quantityHint,
      );
    } catch (_) {
      return null;
    }
  }

  static FoodCategory _inferCategory(String name, List<String> tags) {
    final combined = '${name.toLowerCase()} ${tags.join(' ')}';
    if (combined.contains('beere') ||
        combined.contains('heidelbeer') ||
        combined.contains('himbeer') ||
        combined.contains('erdbeer') ||
        combined.contains('obst') ||
        combined.contains('berries') ||
        combined.contains('fruits')) {
      return FoodCategory.berriesAndFruit;
    }
    if (combined.contains('pizza') || combined.contains('flammkuchen') || combined.contains('baguette')) {
      return FoodCategory.pizzaAndSnacks;
    }
    if (combined.contains('eis') || combined.contains('ice-cream') || combined.contains('sorbet')) {
      return FoodCategory.iceCreamAndDessert;
    }
    if (combined.contains('fisch') ||
        combined.contains('lachs') ||
        combined.contains('garnele') ||
        combined.contains('seafood') ||
        combined.contains('fishes')) {
      return FoodCategory.fishAndSeafood;
    }
    if (combined.contains('fleisch') ||
        combined.contains('rind') ||
        combined.contains('hähnchen') ||
        combined.contains('geflügel') ||
        combined.contains('schnitzel') ||
        combined.contains('meats')) {
      return FoodCategory.meatAndPoultry;
    }
    if (combined.contains('brot') ||
        combined.contains('brötchen') ||
        combined.contains('brezel') ||
        combined.contains('breads')) {
      return FoodCategory.breadAndBakery;
    }
    if (combined.contains('gemüse') ||
        combined.contains('spinat') ||
        combined.contains('erbsen') ||
        combined.contains('kräuter') ||
        combined.contains('vegetables')) {
      return FoodCategory.vegetablesAndHerbs;
    }
    return FoodCategory.cookedAndMeals;
  }
}
