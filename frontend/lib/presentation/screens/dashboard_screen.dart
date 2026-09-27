import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_seeder.dart';
import '../providers/dashboard_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback? onScanTapped;
  final ValueChanged<String>? onInvoiceTapped;

  const DashboardScreen({
    super.key,
    this.onScanTapped,
    this.onInvoiceTapped,
  });

  Future<void> _refreshAll(WidgetRef ref) async {
    await ref.read(openInvoicesProvider.notifier).refresh();
    await ref.read(patientListProvider.notifier).refresh();
    await ref.read(inventoryListProvider.notifier).refresh();
    ref.invalidate(dashboardMetricsProvider);
  }

  void _seedDemoData(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seeding demo clinical data into Supabase...')),
    );
    await SupabaseSeeder.seedInitialClinicalData();
    await _refreshAll(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clinical data synchronized!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(currentStaffProfileProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final metrics = metricsAsync.value ?? DashboardMetrics.empty();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              staff != null ? 'Hello, ${staff.fullName}' : 'PrimaCare Mobile Clinic',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    staff?.role.name.toUpperCase() ?? 'NURSE',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Connected to Supabase',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Seed Initial Data',
            icon: const Icon(Icons.cloud_sync, color: Colors.white),
            onPressed: () => _seedDemoData(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(ref),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Stats Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  StatCard(
                    icon: '🧾',
                    value: '${metrics.openInvoicesCount}',
                    label: 'Open invoices',
                    valueColor: AppColors.primary,
                  ),
                  StatCard(
                    icon: '👥',
                    value: '${metrics.todayPatientsCount}',
                    label: 'Total Patients',
                    valueColor: AppColors.accent,
                  ),
                  StatCard(
                    icon: '⚠️',
                    value: '${metrics.expiryAlertsCount}',
                    label: 'Expiry alerts',
                    valueColor: AppColors.warning,
                  ),
                  StatCard(
                    icon: '💰',
                    value: '₱${metrics.billedTodayAmount.toStringAsFixed(0)}',
                    label: 'Total Billed',
                    valueColor: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mobile Primary Action Button
              ElevatedButton(
                onPressed: onScanTapped,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Scan Item to Bill (Point of Care)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Dynamic Recent Invoices Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Active Invoices',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${metrics.recentInvoices.length} invoices',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (metrics.recentInvoices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      const Text(
                        'No open invoices yet.',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "Seed Initial Data" above or register a patient.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                ...metrics.recentInvoices.map((inv) {
                  final patientName = inv.patientName ??
                      (inv.patientId.length >= 4
                          ? 'Patient ${inv.patientId.substring(0, 4)}'
                          : 'Patient ${inv.patientId}');
                  final initials = patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        onTap: () => onInvoiceTapped?.call(inv.id),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            inv.isOpen ? StatusBadge.open() : StatusBadge.paid(),
                            const SizedBox(width: 8),
                            Text(
                              '${inv.lineItems.length} items',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${inv.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              inv.createdAt != null
                                  ? '${inv.createdAt!.hour}:${inv.createdAt!.minute.toString().padLeft(2, '0')}'
                                  : 'Today',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
