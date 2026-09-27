import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/invoice.dart';
import 'invoice_provider.dart';
import 'inventory_provider.dart';
import 'patient_provider.dart';

class DashboardMetrics {
  final int openInvoicesCount;
  final int todayPatientsCount;
  final int expiryAlertsCount;
  final double billedTodayAmount;
  final List<Invoice> recentInvoices;

  const DashboardMetrics({
    required this.openInvoicesCount,
    required this.todayPatientsCount,
    required this.expiryAlertsCount,
    required this.billedTodayAmount,
    required this.recentInvoices,
  });

  factory DashboardMetrics.empty() {
    return const DashboardMetrics(
      openInvoicesCount: 0,
      todayPatientsCount: 0,
      expiryAlertsCount: 0,
      billedTodayAmount: 0.0,
      recentInvoices: [],
    );
  }
}

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final invoices = await ref.watch(openInvoicesProvider.future);
  final patients = await ref.watch(patientListProvider.future);
  final expiringBatches = await ref.watch(expiringBatchesProvider.future);

  final openCount = invoices.where((i) => i.isOpen).length;
  final double billedSum = invoices.fold(0.0, (acc, i) => acc + i.totalAmount);

  return DashboardMetrics(
    openInvoicesCount: openCount,
    todayPatientsCount: patients.length,
    expiryAlertsCount: expiringBatches.length,
    billedTodayAmount: billedSum,
    recentInvoices: invoices.take(5).toList(),
  );
});
