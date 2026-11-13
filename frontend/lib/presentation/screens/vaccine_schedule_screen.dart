import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/patient.dart';
import '../../domain/models/invoice.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/status_badge.dart';

class VaccineScheduleScreen extends ConsumerStatefulWidget {
  final String? initialPatientId;

  const VaccineScheduleScreen({
    super.key,
    this.initialPatientId,
  });

  @override
  ConsumerState<VaccineScheduleScreen> createState() => _VaccineScheduleScreenState();
}

class _VaccineScheduleScreenState extends ConsumerState<VaccineScheduleScreen> {
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.initialPatientId;
  }

  void _showRecordDoseDialog(Patient patient) {
    final inventory = (ref.read(inventoryListProvider).value ?? [])
        .where((i) => i.category.toLowerCase().contains('vaccine'))
        .toList();

    if (inventory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No vaccine formulary items in inventory. Please seed or receive vaccines first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    String selectedItemId = inventory.first.id;
    String selectedItemName = inventory.first.name;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          title: Text('Record Immunization for ${patient.fullName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Select Vaccine from Clinic Stock:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedItemId,
                isExpanded: true,
                items: inventory.map((item) {
                  return DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.name} (${item.totalStock} in stock)', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() {
                      selectedItemId = val;
                      final match = inventory.where((i) => i.id == val).firstOrNull;
                      if (match != null) selectedItemName = match.name;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'FEFO Rule: Dispensation will allocate the oldest non-expired batch from Supabase.',
                style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogCtx);

                final selectedItem = inventory.where((i) => i.id == selectedItemId).firstOrNull;
                if (selectedItem == null ||
                    selectedItem.barcode == null ||
                    selectedItem.barcode!.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Selected vaccine has no barcode configured for dispensation.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                if (selectedItem.totalStock < 1) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Insufficient stock for ${selectedItem.name} (${selectedItem.totalStock} available).'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                // 1. Find or open an invoice for this patient
                final invoices = ref.read(openInvoicesProvider).value ?? [];
                var inv = invoices.where((i) => i.patientId == patient.id && i.isOpen).firstOrNull;
                inv ??= await ref.read(openInvoicesProvider.notifier).createInvoiceForPatient(
                      patientId: patient.id,
                      patientName: patient.fullName,
                    );

                // 2. Atomically dispense via FEFO RPC / repository (validates stock & links batch)
                final result = await ref.read(openInvoicesProvider.notifier).dispenseBarcode(
                      barcode: selectedItem.barcode!,
                      invoiceId: inv.id,
                      quantity: 1,
                    );

                if (!result.success) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(result.message ?? 'Unable to record dose: insufficient stock.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                // 3. Queue an automatic booster notification for 30 days ahead
                await ref.read(notificationListProvider.notifier).scheduleVaccineReminder(
                      patientId: patient.id,
                      patientName: patient.fullName,
                      vaccineName: '$selectedItemName Next Booster / Follow-up',
                      dueDate: DateTime.now().add(const Duration(days: 30)),
                    );

                await ref.read(inventoryListProvider.notifier).refresh();
                ref.invalidate(expiringBatchesProvider);

                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Successfully recorded dose of $selectedItemName for ${patient.fullName}!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Confirm & Record Dose'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(currentUserRoleProvider);
    final patientsAsync = ref.watch(patientListProvider);
    ref.watch(inventoryListProvider);
    final patients = patientsAsync.value ?? [];

    Patient? selectedPatient;
    if (patients.isNotEmpty) {
      selectedPatient = patients.where((p) => p.id == _selectedPatientId).firstOrNull ?? patients.first;
      _selectedPatientId ??= selectedPatient.id;
    }

    final allInvoices = ref.watch(openInvoicesProvider).value ?? [];
    final patientInvoices = selectedPatient != null
        ? allInvoices.where((i) => i.patientId == selectedPatient?.id).toList()
        : <Invoice>[];

    final Set<String> dispensedVaccines = {};
    for (final inv in patientInvoices) {
      for (final li in inv.lineItems) {
        final nameLower = li.itemName.toLowerCase();
        if (nameLower.contains('vaccine') ||
            nameLower.contains('hepa') ||
            nameLower.contains('bcg') ||
            nameLower.contains('mmr') ||
            nameLower.contains('pentavalent') ||
            nameLower.contains('influenza')) {
          dispensedVaccines.add(li.itemName);
        }
      }
    }

    final standardSchedule = [
      {'name': 'BCG (Bacillus Calmette–Guérin)', 'timing': 'Completed · At Birth / 1 Mo', 'key': 'bcg'},
      {'name': 'Hepatitis B Pediatric Vaccine', 'timing': 'Completed · Dose 1 (Birth)', 'key': 'hepa'},
      {'name': 'Pentavalent (DTP-HepB-Hib)', 'timing': 'Recommended · 6 Weeks', 'key': 'pentavalent'},
      {'name': 'MMR (Measles, Mumps, Rubella)', 'timing': 'Scheduled · Next Due (9 Mos)', 'key': 'mmr'},
      {'name': 'Influenza (Quadrivalent Seasonal)', 'timing': 'Recommended · Annual Seasonal', 'key': 'influenza'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Vaccine Schedule & Immunization',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: patientsAsync.isLoading && patients.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (patients.isNotEmpty && selectedPatient != null) ...[
                  _buildPatientPicker(patients, selectedPatient),
                  const SizedBox(height: 16),
                  _buildPatientHeader(selectedPatient),
                ] else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text('No patients registered in clinic yet.'),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Immunization Timeline (DOH / CDC)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (userRole.canDispense)
                      TextButton.icon(
                        onPressed: selectedPatient != null ? () => _showRecordDoseDialog(selectedPatient!) : null,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Record Dose', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ...standardSchedule.map((sched) {
                  final name = sched['name']!;
                  final timing = sched['timing']!;
                  final key = sched['key']!;
                  final isDone = dispensedVaccines.any((v) => v.toLowerCase().contains(key));

                  return _buildDoseCard(
                    vaccine: name,
                    date: isDone ? 'Administered & Recorded' : timing,
                    batch: isDone ? 'Dispensed on Patient Encounter' : 'Awaiting Clinic Point-of-Care Allocation',
                    isDone: isDone,
                    onTap: () => _showDoseDetailModal(
                      vaccine: name,
                      statusText: isDone ? 'Administered & Recorded' : timing,
                      isDone: isDone,
                      patient: selectedPatient,
                      canDispense: userRole.canDispense,
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildPatientPicker(List<Patient> patients, Patient current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_search, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          const Text('Patient: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current.id,
                isExpanded: true,
                items: patients.map((p) {
                  return DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      '${p.fullName} (${p.sex ?? "N/A"}, ${(p.allergies == null || p.allergies!.isEmpty) ? "No allergies" : "Allergies: ${p.allergies}"})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    setState(() => _selectedPatientId = id);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeader(Patient patient) {
    final initials = patient.fullName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                radius: 24,
                child: Text(
                  initials.isNotEmpty ? initials : 'P',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DOB: ${patient.dateOfBirth ?? "Not specified"} · ${patient.sex ?? "N/A"} · Contact: ${patient.contactNumber ?? "N/A"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (patient.allergies != null && patient.allergies!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Known Allergies: ${patient.allergies}',
                      style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDoseDetailModal({
    required String vaccine,
    required String statusText,
    required bool isDone,
    required Patient? patient,
    required bool canDispense,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Immunization Dose Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vaccine, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(statusText, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (patient != null) ...[
              const SizedBox(height: 6),
              Text('Patient: ${patient.fullName}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (!isDone && patient != null && canDispense)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showRecordDoseDialog(patient);
              },
              child: const Text('Record Dose'),
            ),
        ],
      ),
    );
  }

  Widget _buildDoseCard({
    required String vaccine,
    required String date,
    required String batch,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.verified : Icons.schedule,
                  color: isDone ? AppColors.success : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vaccine, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(batch, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                isDone ? StatusBadge.paid() : StatusBadge.open(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
