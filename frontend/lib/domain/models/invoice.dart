class InvoiceLineItem {
  final String id;
  final String invoiceId;
  final String? inventoryBatchId;
  final String itemName;
  final int quantity;
  final double unitCost;

  const InvoiceLineItem({
    required this.id,
    required this.invoiceId,
    this.inventoryBatchId,
    required this.itemName,
    required this.quantity,
    required this.unitCost,
  });

  double get lineTotal => quantity * unitCost;

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      id: json['id'] as String,
      invoiceId: json['invoice_id'] as String,
      inventoryBatchId: json['inventory_batch_id'] as String?,
      itemName: json['item_name'] as String? ?? 'Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'inventory_batch_id': inventoryBatchId,
      'item_name': itemName,
      'quantity': quantity,
      'unit_cost': unitCost,
    };
  }
}

class Invoice {
  final String id;
  final String patientId;
  final String? patientName;
  final String? createdBy;
  final String status;
  final double totalAmount;
  final DateTime? createdAt;
  final List<InvoiceLineItem> lineItems;

  const Invoice({
    required this.id,
    required this.patientId,
    this.patientName,
    this.createdBy,
    this.status = 'open',
    this.totalAmount = 0.0,
    this.createdAt,
    this.lineItems = const [],
  });

  bool get isOpen => status == 'open';
  bool get isPaid => status == 'paid';

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String?,
      createdBy: json['created_by'] as String?,
      status: json['status'] as String? ?? 'open',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      lineItems: (json['line_items'] as List<dynamic>?)
              ?.map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'status': status,
      'total_amount': totalAmount,
    };
  }
}
