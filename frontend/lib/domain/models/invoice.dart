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

  // Outpatient Statutory Discounts (Philippine RA 9994 / RA 10754)
  final String discountType; // 'none' | 'senior' | 'pwd' | 'custom'
  final double discountPercentage;
  final String? discountIdNumber;

  const Invoice({
    required this.id,
    required this.patientId,
    this.patientName,
    this.createdBy,
    this.status = 'open',
    this.totalAmount = 0.0,
    this.createdAt,
    this.lineItems = const [],
    this.discountType = 'none',
    this.discountPercentage = 0.0,
    this.discountIdNumber,
  });

  bool get isOpen => status == 'open';
  bool get isPaid => status == 'paid';

  /// Gross bill before discounts or VAT deductions
  double get grossAmount => totalAmount;

  /// Whether a Senior Citizen or PWD statutory discount is applied
  bool get hasSeniorOrPwdDiscount =>
      discountType == 'senior' || discountType == 'pwd';

  /// Vatable Base: Gross divided by 1.12 (12% VAT in the Philippines)
  double get vatableBase => grossAmount > 0 ? grossAmount / 1.12 : 0.0;

  /// Statutory 12% VAT Exemption amount under RA 9994 / RA 10754
  double get vatExemptionAmount =>
      hasSeniorOrPwdDiscount ? (grossAmount - vatableBase) : 0.0;

  /// 12% VAT amount for regular walk-in patients
  double get regularVatAmount =>
      hasSeniorOrPwdDiscount ? 0.0 : (grossAmount - vatableBase);

  /// Calculated discount deduction (20% for Senior/PWD off vatable base, or % off gross for custom)
  double get discountAmount {
    if (hasSeniorOrPwdDiscount) {
      return vatableBase * 0.20;
    }
    if (discountPercentage > 0) {
      return grossAmount * (discountPercentage / 100.0);
    }
    return 0.0;
  }

  /// Final Net Amount due from the patient
  double get netPayable {
    if (hasSeniorOrPwdDiscount) {
      return vatableBase - discountAmount;
    }
    final net = grossAmount - discountAmount;
    return net > 0 ? net : 0.0;
  }

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
      discountType: json['discount_type'] as String? ?? 'none',
      discountPercentage:
          (json['discount_percentage'] as num?)?.toDouble() ?? 0.0,
      discountIdNumber: json['discount_id_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'status': status,
      'total_amount': totalAmount,
      'discount_type': discountType,
      'discount_percentage': discountPercentage,
      if (discountIdNumber != null) 'discount_id_number': discountIdNumber,
    };
  }

  Invoice copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? createdBy,
    String? status,
    double? totalAmount,
    DateTime? createdAt,
    List<InvoiceLineItem>? lineItems,
    String? discountType,
    double? discountPercentage,
    String? discountIdNumber,
  }) {
    return Invoice(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      lineItems: lineItems ?? this.lineItems,
      discountType: discountType ?? this.discountType,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountIdNumber: discountIdNumber ?? this.discountIdNumber,
    );
  }
}
