import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/models/report_item.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

final monthlyBillingProvider = FutureProvider<List<BillingSummaryReport>>((ref) async {
  final repo = ref.read(reportRepositoryProvider);
  return repo.getMonthlyBillingSummary();
});

final leakageRecoveryProvider = FutureProvider<List<LeakageRecoveryReport>>((ref) async {
  final repo = ref.read(reportRepositoryProvider);
  return repo.getLeakageRecoveryReport();
});
