import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/report_item.dart';
import '../services/supabase_service.dart';

class ReportRepository {
  final SupabaseClient? _client;

  ReportRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  Future<List<BillingSummaryReport>> getMonthlyBillingSummary() async {
    if (_client == null) {
      return _mockMonthlySummaries;
    }

    try {
      final response = await _client.from('view_monthly_billing_summary').select();
      return (response as List)
          .map((row) => BillingSummaryReport.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockMonthlySummaries;
    }
  }

  Future<List<LeakageRecoveryReport>> getLeakageRecoveryReport() async {
    if (_client == null) {
      return _mockLeakageReports;
    }

    try {
      final response = await _client.from('view_revenue_leakage_prevented').select();
      return (response as List)
          .map((row) => LeakageRecoveryReport.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockLeakageReports;
    }
  }

  String exportReportsAsCsv({
    required List<BillingSummaryReport> billingSummaries,
    required List<LeakageRecoveryReport> leakageReports,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('--- PRIMACARE FINANCIAL & CLINICAL SUMMARY REPORT ---');
    buffer.writeln('Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('Month,Total Invoices,Paid Invoices,Open Invoices,Total Billed,Total Collected,Collection Rate (%)');
    for (final b in billingSummaries) {
      buffer.writeln(
        '${b.monthKey},${b.totalInvoices},${b.paidInvoices},${b.openInvoices},${b.totalBilledAmount},${b.totalCollectedAmount},${b.collectionRate.toStringAsFixed(1)}',
      );
    }
    buffer.writeln();
    buffer.writeln('Item Name,Dispensation Count,Units Dispensed,Revenue Captured (PHP)');
    for (final l in leakageReports) {
      buffer.writeln(
        '"${l.itemName}",${l.dispensationCount},${l.totalUnitsDispensed},${l.totalRevenueCaptured}',
      );
    }
    return buffer.toString();
  }

  static final List<BillingSummaryReport> _mockMonthlySummaries = [
    const BillingSummaryReport(
      monthKey: '2026-09',
      totalInvoices: 48,
      paidInvoices: 42,
      openInvoices: 6,
      totalBilledAmount: 148200.0,
      totalCollectedAmount: 130000.0,
    ),
    const BillingSummaryReport(
      monthKey: '2026-08',
      totalInvoices: 36,
      paidInvoices: 33,
      openInvoices: 3,
      totalBilledAmount: 112000.0,
      totalCollectedAmount: 104500.0,
    ),
  ];

  static final List<LeakageRecoveryReport> _mockLeakageReports = [
    const LeakageRecoveryReport(
      itemName: 'Hepatitis B Pediatric Vaccine',
      dispensationCount: 21,
      totalUnitsDispensed: 21,
      totalRevenueCaptured: 9450.0,
    ),
    const LeakageRecoveryReport(
      itemName: 'Disposable Syringe 3ml',
      dispensationCount: 208,
      totalUnitsDispensed: 208,
      totalRevenueCaptured: 5200.0,
    ),
    const LeakageRecoveryReport(
      itemName: 'Paracetamol 500mg Tablets',
      dispensationCount: 690,
      totalUnitsDispensed: 690,
      totalRevenueCaptured: 3795.0,
    ),
  ];
}
