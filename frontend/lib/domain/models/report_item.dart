class BillingSummaryReport {
  final String monthKey;
  final int totalInvoices;
  final int paidInvoices;
  final int openInvoices;
  final double totalBilledAmount;
  final double totalCollectedAmount;

  const BillingSummaryReport({
    required this.monthKey,
    required this.totalInvoices,
    required this.paidInvoices,
    required this.openInvoices,
    required this.totalBilledAmount,
    required this.totalCollectedAmount,
  });

  double get collectionRate =>
      totalBilledAmount > 0 ? (totalCollectedAmount / totalBilledAmount) * 100 : 0.0;

  factory BillingSummaryReport.fromJson(Map<String, dynamic> json) {
    return BillingSummaryReport(
      monthKey: json['month_key'] as String? ?? '',
      totalInvoices: (json['total_invoices'] as num?)?.toInt() ?? 0,
      paidInvoices: (json['paid_invoices'] as num?)?.toInt() ?? 0,
      openInvoices: (json['open_invoices'] as num?)?.toInt() ?? 0,
      totalBilledAmount: (json['total_billed_amount'] as num?)?.toDouble() ?? 0.0,
      totalCollectedAmount: (json['total_collected_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LeakageRecoveryReport {
  final String itemName;
  final int dispensationCount;
  final int totalUnitsDispensed;
  final double totalRevenueCaptured;

  const LeakageRecoveryReport({
    required this.itemName,
    required this.dispensationCount,
    required this.totalUnitsDispensed,
    required this.totalRevenueCaptured,
  });

  double get averageUnitRevenue =>
      totalUnitsDispensed > 0 ? totalRevenueCaptured / totalUnitsDispensed : 0.0;

  factory LeakageRecoveryReport.fromJson(Map<String, dynamic> json) {
    return LeakageRecoveryReport(
      itemName: json['item_name'] as String? ?? '',
      dispensationCount: (json['dispensation_count'] as num?)?.toInt() ?? 0,
      totalUnitsDispensed: (json['total_units_dispensed'] as num?)?.toInt() ?? 0,
      totalRevenueCaptured: (json['total_revenue_captured'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
