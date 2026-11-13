import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_seeder.dart';
import '../../domain/models/invoice.dart';
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

  void _confirmInitializeClinicData(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Initialize Clinic Essentials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'Synchronize core clinic formulary items and seed baseline clinical data with Supabase?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _initializeClinicData(context, ref);
            },
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
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

  void _showInvoicesModal(
    BuildContext context, {
    required String title,
    required List<Invoice> invoices,
    required String emptyMessage,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              if (invoices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: invoices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final inv = invoices[idx];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          title: Text(inv.patientName ?? 'Patient ${inv.patientId}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('${inv.lineItems.length} items · ${inv.status.toUpperCase()}', style: const TextStyle(fontSize: 12)),
                          trailing: Text('₱${inv.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          onTap: () {
                            Navigator.pop(ctx);
                            onInvoiceTapped?.call(inv.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientsModal(BuildContext context, WidgetRef ref) {
    final patients = ref.read(patientListProvider).value ?? [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Registered Patients (${patients.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              if (patients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No patients registered yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: patients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final pat = patients[idx];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Text(pat.fullName.isNotEmpty ? pat.fullName[0].toUpperCase() : 'P', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          ),
                          title: Text(pat.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(pat.contactNumber ?? 'No phone recorded', style: const TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onNavigateTab?.call(1);
                },
                child: const Text('Open Patients Directory'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpiringBatchesModal(BuildContext context, WidgetRef ref) {
    final batches = ref.read(expiringBatchesProvider).value ?? [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Expiring Batches (<30d: ${batches.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              if (batches.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('All active inventory batches are safe (>30 days shelf life).', textAlign: TextAlign.center, style: TextStyle(color: AppColors.success, fontSize: 13)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: batches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final b = batches[idx];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          title: Text(b.itemName ?? 'Batch #${b.batchNumber}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('Batch #${b.batchNumber} · ${b.quantityRemaining} units · ${b.daysUntilExpiry}d left', style: const TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onNavigateTab?.call(6);
                },
                child: const Text('Open Expiry Alerts'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(currentStaffProfileProvider);
    final userRole = ref.watch(currentUserRoleProvider);
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
                    staff?.role.displayLabel ?? userRole.displayLabel,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    staff?.clinic.name ?? 'Central Clinic',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (userRole.canSeedData)
            IconButton(
              tooltip: 'Initialize Clinic Essentials',
              icon: const Icon(Icons.cloud_sync, color: Colors.white),
              onPressed: () => _confirmInitializeClinicData(context, ref),
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
                    icon: Icons.payments_outlined,
                    value: '₱${collectedToday.toStringAsFixed(0)}',
                    label: 'Collected Today',
                    valueColor: AppColors.success,
                    onTap: () => _showInvoicesModal(
                      context,
                      title: 'Collected Today Breakdown',
                      invoices: allInvoices.where((i) => i.isPaid).toList(),
                      emptyMessage: 'No paid invoices recorded yet.',
                    ),
                  ),
                  StatCard(
                    icon: Icons.receipt_long_outlined,
                    value: '₱${unpaidReceivables.toStringAsFixed(0)}',
                    label: 'Unpaid Receivables',
                    valueColor: AppColors.warning,
                    onTap: () => _showInvoicesModal(
                      context,
                      title: 'Unpaid Receivables Breakdown',
                      invoices: allInvoices.where((i) => !i.isPaid).toList(),
                      emptyMessage: 'No unpaid invoices! All bills settled.',
                    ),
                  ),
                  StatCard(
                    icon: Icons.people_outline,
                    value: '${metrics.todayPatientsCount}',
                    label: 'Total Patients',
                    valueColor: AppColors.accent,
                    onTap: () => _showPatientsModal(context, ref),
                  ),
                  StatCard(
                    icon: Icons.warning_amber_rounded,
                    value: '${metrics.expiryAlertsCount}',
                    label: 'Expiring Batches (<30d)',
                    valueColor: AppColors.danger,
                    onTap: () => _showExpiringBatchesModal(context, ref),
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
                  if (userRole.canReceiveStock) ...[
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
                ],
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
}
