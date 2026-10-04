class InventoryItem {
  final String id;
  final String name;
  final String? barcode;
  final String unit;
  final double unitCost;
  final String category;
  final int reorderLevel;
  final int totalStock;

  const InventoryItem({
    required this.id,
    required this.name,
    this.barcode,
    this.unit = 'piece',
    this.unitCost = 0.0,
    this.category = 'consumable',
    this.reorderLevel = 10,
    this.totalStock = 0,
  });

  bool get isLowStock => totalStock <= reorderLevel;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? barcode,
    String? unit,
    double? unitCost,
    String? category,
    int? reorderLevel,
    int? totalStock,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
      category: category ?? this.category,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      totalStock: totalStock ?? this.totalStock,
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      barcode: json['barcode'] as String?,
      unit: json['unit'] as String? ?? 'piece',
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'consumable',
      reorderLevel: (json['reorder_level'] as num?)?.toInt() ?? 10,
      totalStock: (json['total_stock'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'unit': unit,
      'unit_cost': unitCost,
      'category': category,
      'reorder_level': reorderLevel,
      'total_stock': totalStock,
    };
  }
}

class InventoryBatch {
  final String id;
  final String itemId;
  final String batchNumber;
  final int quantityRemaining;
  final DateTime expiryDate;
  final DateTime receivedDate;

  const InventoryBatch({
    required this.id,
    required this.itemId,
    required this.batchNumber,
    required this.quantityRemaining,
    required this.expiryDate,
    required this.receivedDate,
  });

  bool get isExpired => expiryDate.isBefore(DateTime.now());
  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
  bool get isCriticalExpiry => daysUntilExpiry <= 30 && daysUntilExpiry >= 0;

  InventoryBatch copyWith({
    String? id,
    String? itemId,
    String? batchNumber,
    int? quantityRemaining,
    DateTime? expiryDate,
    DateTime? receivedDate,
  }) {
    return InventoryBatch(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      batchNumber: batchNumber ?? this.batchNumber,
      quantityRemaining: quantityRemaining ?? this.quantityRemaining,
      expiryDate: expiryDate ?? this.expiryDate,
      receivedDate: receivedDate ?? this.receivedDate,
    );
  }

  factory InventoryBatch.fromJson(Map<String, dynamic> json) {
    return InventoryBatch(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      batchNumber: json['batch_number'] as String? ?? '',
      quantityRemaining: (json['quantity_remaining'] as num?)?.toInt() ?? 0,
      expiryDate: DateTime.tryParse(json['expiry_date'] as String? ?? '') ?? DateTime.now(),
      receivedDate: DateTime.tryParse(json['received_date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
