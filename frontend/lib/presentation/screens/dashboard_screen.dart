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
  final ValueChanged<int>? onNavigateTab;
  final ValueChanged<String>? onNewEncounterStarted;

  const DashboardScreen({
    super.key,
    this.onScanTapped,
    this.onInvoiceTapped,
    this.onNavigateTab,
    this.onNewEncounterStarted,
  });

  Future<void> _refreshAll(WidgetRef ref) async {
    await ref.read(openInvoicesProvider.notifier).refresh();
    await ref.read(patientListProvider.notifier).refresh();
    await ref.read(inventoryListProvider.notifier).refresh();
    ref.invalidate(dashboardMetricsProvider);
  }

  void _initializeClinicData(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Synchronizing clinical essentials with Supabase...')),
    );
    await SupabaseSeeder.seedInitialClinicalData();
    await _refreshAll(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clinic essentials & formulary ready!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showQuickNewEncounterDialog(BuildContext context, WidgetRef ref) {
    final patients = ref.read(patientListProvider).value ?? [];
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register a patient first.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    String selectedPatientId = patients.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final pat = patients.where((p) => p.id == selectedPatientId).firstOrNull ?? patients.first;
          selectedPatientId = pat.id;

          return AlertDialog(
            title: const Text('Start New Patient Encounter / Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Select Patient for Consultation:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedPatientId,
                  isExpanded: true,
                  items: patients
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.fullName} (${p.contactNumber ?? 'No phone'})', style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedPatientId = val);
                  },
                ),
                const SizedBox(height: 12),
                if (pat.allergies != null && pat.allergies!.isNotEmpty && pat.allergies != 'None recorded')
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Allergies: ${pat.allergies}', style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final inv = await ref
                      .read(openInvoicesProvider.notifier)
                      .createInvoiceForPatient(
                        patientId: pat.id,
                        patientName: pat.fullName,
                      );
                  onNewEncounterStarted?.call(inv.id);
                  onInvoiceTapped?.call(inv.id);
                },
                child: const Text('Open Invoice'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(currentStaffProfileProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final metrics = metricsAsync.value ?? DashboardMetrics.empty();

    final allInvoices = ref.watch(openInvoicesProvider).value ?? [];
    double collectedToday = 0.0;
    double unpaidReceivables = 0.0;
    for (final inv in allInvoices) {
      if (inv.isPaid) {
        collectedToday += inv.totalAmount;
      } else {
        unpaidReceivables += inv.totalAmount;
      }
    }

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
              staff != null ? 'Hello, ${staff.fullName}' : 'PrimaCare Clinic',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
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
                    staff?.role.name.toUpperCase() ?? 'ADMIN / OWNER',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  staff?.clinic.name ?? 'Central Clinic',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Initialize Clinic Essentials',
            icon: const Icon(Icons.cloud_sync, color: Colors.white),
            onPressed: () => _initializeClinicData(context, ref),
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
                childAspectRatio: 1.55,
                children: [
                  StatCard(
                    icon: '💰',
                    value: '₱${collectedToday.toStringAsFixed(0)}',
                    label: 'Collected Today',
                    valueColor: AppColors.success,
                  ),
                  StatCard(
                    icon: '🧾',
                    value: '₱${unpaidReceivables.toStringAsFixed(0)}',
                    label: 'Unpaid Receivables',
                    valueColor: AppColors.warning,
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
                    label: 'Expiring Batches (<30d)',
                    valueColor: AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Owner Quick Action Bar
              const Text(
                'Clinic Operations Shortcuts',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showQuickNewEncounterDialog(context, ref),
                      icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                      label: const Text('New Encounter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onScanTapped,
                      icon: const Icon(Icons.qr_code_scanner, size: 16, color: Colors.white),
                      label: const Text('Scan & Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onNavigateTab?.call(1), // Patients tab
                      icon: const Icon(Icons.person_add_alt_1, size: 16, color: AppColors.primary),
                      label: const Text('Patients', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onNavigateTab?.call(5), // QR & Barcodes tab
                      icon: const Icon(Icons.qr_code_2, size: 16, color: AppColors.accent),
                      label: const Text('Barcodes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onNavigateTab?.call(7), // Receive stock tab (index 7)
                      icon: const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textPrimary),
                      label: const Text('Stock In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Clinic Operations Roadmap & Verification Card for New Users
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        const Text(
                          'Clinic Operational Roadmap & Assurance',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'SYSTEM ACTIVE',
                            style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      stepNumber: '1',
                      title: 'Enroll Patient',
                      description: 'Add patient records with allergy warnings and contact numbers.',
                      actionText: 'Directory',
                      onTap: () => onNavigateTab?.call(1),
                    ),
                    const Divider(height: 16),
                    _buildStepRow(
                      stepNumber: '2',
                      title: 'Inventory & Barcodes',
                      description: 'Formulary items have auto-generated barcodes ready for label printing.',
                      actionText: 'Barcodes',
                      onTap: () => onNavigateTab?.call(5),
                    ),
                    const Divider(height: 16),
                    _buildStepRow(
                      stepNumber: '3',
                      title: 'Scan & Dispense',
                      description: 'Point camera or USB scanner gun to auto-deduct earliest batch (FIFO).',
                      actionText: 'Scanner',
                      onTap: onScanTapped,
                    ),
                    const Divider(height: 16),
                    _buildStepRow(
                      stepNumber: '4',
                      title: 'Settle Bill & Print Receipt',
                      description: 'Collect payment, mark invoice as paid, and print 58mm ESC/POS receipt.',
                      actionText: 'Invoices',
                      onTap: () => onNavigateTab?.call(2),
                    ),
                  ],
                ),
              ),

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
                        'Tap "New Encounter" above or register a patient.',
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

  Widget _buildStepRow({
    required String stepNumber,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback? onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            stepNumber,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }
}
