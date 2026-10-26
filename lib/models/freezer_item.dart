import 'freezer_compartment.dart';

enum FreshnessStatus {
  fresh,
  expiringSoon,
  expired,
}

class FreezerItem {
  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final String compartmentId;
  final FoodCategory category;
  final double quantity;
  final String unit;
  final DateTime frozenAt;
  final DateTime expiresAt;
  final String? notes;
  final String? imageUrl;
  final String? thumbnailBase64;
  final String? localImagePath;
  final String addedByPubkey;
  final String addedByName;
  final DateTime updatedAt;
  final bool isIcePackInUse;

  const FreezerItem({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.compartmentId,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.frozenAt,
    required this.expiresAt,
    this.notes,
    this.imageUrl,
    this.thumbnailBase64,
    this.localImagePath,
    required this.addedByPubkey,
    required this.addedByName,
    required this.updatedAt,
    this.isIcePackInUse = false,
  });

  int calculateDaysUntilExpiration([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return expiresAt.difference(DateTime(reference.year, reference.month, reference.day)).inDays;
  }

  int get daysUntilExpiration => calculateDaysUntilExpiration();

  int get daysInFreezer {
    final now = DateTime.now();
    return now.difference(DateTime(frozenAt.year, frozenAt.month, frozenAt.day)).inDays;
  }

  FreshnessStatus get freshnessStatus {
    if (category == FoodCategory.icePacks) {
      return FreshnessStatus.fresh;
    }
    final days = daysUntilExpiration;
    if (days < 0) {
      return FreshnessStatus.expired;
    } else if (days <= 21) {
      return FreshnessStatus.expiringSoon;
    }
    return FreshnessStatus.fresh;
  }

  String get formattedQuantity {
    final isWhole = quantity == quantity.roundToDouble();
    final numStr = isWhole ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
    return '$numStr $unit';
  }

  bool get needsR2Upload {
    return (imageUrl == null || imageUrl!.isEmpty) &&
        ((localImagePath != null && localImagePath!.isNotEmpty) ||
            (thumbnailBase64 != null && thumbnailBase64!.isNotEmpty));
  }

  FreezerItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? barcode,
    String? compartmentId,
    FoodCategory? category,
    double? quantity,
    String? unit,
    DateTime? frozenAt,
    DateTime? expiresAt,
    String? notes,
    String? imageUrl,
    String? thumbnailBase64,
    String? localImagePath,
    String? addedByPubkey,
    String? addedByName,
    DateTime? updatedAt,
    bool? isIcePackInUse,
  }) {
    return FreezerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      compartmentId: compartmentId ?? this.compartmentId,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      frozenAt: frozenAt ?? this.frozenAt,
      expiresAt: expiresAt ?? this.expiresAt,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      localImagePath: localImagePath ?? this.localImagePath,
      addedByPubkey: addedByPubkey ?? this.addedByPubkey,
      addedByName: addedByName ?? this.addedByName,
      updatedAt: updatedAt ?? this.updatedAt,
      isIcePackInUse: isIcePackInUse ?? this.isIcePackInUse,
    );
  }

  Map<String, dynamic> toJson({bool includeLocalPath = true}) {
    return {
      'id': id,
      'name': name,
      if (brand != null && brand!.isNotEmpty) 'brand': brand,
      if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      'compartmentId': compartmentId,
      'category': category.id,
      'quantity': quantity,
      'unit': unit,
      'frozenAt': frozenAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (thumbnailBase64 != null && thumbnailBase64!.isNotEmpty)
        'thumbnailBase64': thumbnailBase64,
      if (includeLocalPath && localImagePath != null && localImagePath!.isNotEmpty)
        'localImagePath': localImagePath,
      'addedByPubkey': addedByPubkey,
      'addedByName': addedByName,
      'updatedAt': updatedAt.toIso8601String(),
      'isIcePackInUse': isIcePackInUse,
    };
  }

  factory FreezerItem.fromJson(Map<String, dynamic> json) {
    final frozen = DateTime.tryParse(json['frozenAt']?.toString() ?? '') ?? DateTime.now();
    final category = FoodCategory.fromId(json['category']?.toString());
    final expires = DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
        DateTime(frozen.year, frozen.month + category.recommendedMonths, frozen.day);

    return FreezerItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unbekannter Artikel',
      brand: json['brand']?.toString(),
      barcode: json['barcode']?.toString(),
      compartmentId: json['compartmentId']?.toString() ?? 'drawer_1',
      category: category,
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toDouble()
          : double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
      unit: json['unit']?.toString() ?? 'Stück',
      frozenAt: frozen,
      expiresAt: expires,
      notes: json['notes']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      thumbnailBase64: json['thumbnailBase64']?.toString(),
      localImagePath: json['localImagePath']?.toString(),
      addedByPubkey: json['addedByPubkey']?.toString() ?? '',
      addedByName: json['addedByName']?.toString() ?? 'Haushalt',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      isIcePackInUse: json['isIcePackInUse'] == true,
    );
  }
}
