import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/clinical_encounter.dart';
import '../widgets/status_badge.dart';
import '../providers/invoice_provider.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String dob;
  final String phone;
  final String? sex;
  final String? allergies;
  final String? address;
  final String? emergencyContact;
  final ValueChanged<String>? onStartEncounter;

  const PatientProfileScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.dob,
    required this.phone,
    this.sex,
    this.allergies,
    this.address,
    this.emergencyContact,
    this.onStartEncounter,
  });

  @override
  ConsumerState<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  ClinicalVitals? _latestVitals;

  @override
  void initState() {
    super.initState();
    // Default initial normal baseline vitals for demonstrated patient
    _latestVitals = ClinicalVitals.normalBaseline();
  }

  void _showRecordVitalsDialog() {
    final bpCtrl = TextEditingController(text: _latestVitals?.bloodPressure ?? '120/80');
    final tempCtrl = TextEditingController(text: (_latestVitals?.temperature ?? 36.5).toStringAsFixed(1));
    final hrCtrl = TextEditingController(text: (_latestVitals?.heartRate ?? 72).toStringAsFixed(0));
    final rrCtrl = TextEditingController(text: (_latestVitals?.respiratoryRate ?? 16).toString());
    final wtCtrl = TextEditingController(text: (_latestVitals?.weightKg ?? 60.0).toStringAsFixed(1));
    final complaintCtrl = TextEditingController(text: _latestVitals?.chiefComplaint ?? 'Routine Clinical Checkup');
    final notesCtrl = TextEditingController(text: _latestVitals?.clinicalNotes ?? 'Patient ambulatory, oriented, vitals stable.');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.monitor_heart_outlined, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text('Record Clinical Vitals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1-Tap Preset Button for busy non-tech nurses
                  ElevatedButton.icon(
                    onPressed: () {
                      bpCtrl.text = '120/80';
                      tempCtrl.text = '36.5';
                      hrCtrl.text = '72';
                      rrCtrl.text = '16';
                      wtCtrl.text = '60.0';
                      complaintCtrl.text = 'Routine Clinical Checkup';
                      notesCtrl.text = 'Vitals within normal limits. Patient coherent and stable.';
                      setModalState(() {});
                    },
                    icon: const Icon(Icons.flash_on, size: 16, color: Colors.white),
                    label: const Text('1-Tap Preset: Normal Baseline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bpCtrl,
                          decoration: const InputDecoration(labelText: 'BP (mmHg)', hintText: '120/80'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: tempCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Temp (°C)', hintText: '36.5'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hrCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Heart Rate (bpm)', hintText: '72'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: rrCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Resp. Rate (cpm)', hintText: '16'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: wtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (kg)', hintText: '60.0'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: complaintCtrl,
                    decoration: const InputDecoration(labelText: 'Chief Complaint', hintText: 'e.g. Mild headache, vaccination'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Clinical Notes', hintText: 'Observations, instructions, diagnosis'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final newVitals = ClinicalVitals(
                    bloodPressure: bpCtrl.text.trim().isNotEmpty ? bpCtrl.text.trim() : '120/80',
                    temperature: double.tryParse(tempCtrl.text.trim()) ?? 36.5,
                    heartRate: double.tryParse(hrCtrl.text.trim()) ?? 72.0,
                    respiratoryRate: int.tryParse(rrCtrl.text.trim()) ?? 16,
                    weightKg: double.tryParse(wtCtrl.text.trim()),
                    chiefComplaint: complaintCtrl.text.trim().isNotEmpty ? complaintCtrl.text.trim() : null,
                    clinicalNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                    recordedAt: DateTime.now(),
                  );
                  setState(() => _latestVitals = newVitals);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Patient vital signs and clinical assessment recorded!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                child: const Text('Save Vitals'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allInvoices = ref.watch(openInvoicesProvider).value ?? [];
    final patientInvoices = allInvoices.where((i) => i.patientId == widget.patientId).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: Text(
            widget.patientName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Encounters & Care'),
              Tab(text: 'Vaccine Timeline'),
              Tab(text: 'Reminders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Invoices & Dispensation History + Vitals Triage
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryBox(),
                const SizedBox(height: 14),

                // Vitals & Clinical Triage Card
                _buildVitalsCard(),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Clinical Encounters & Invoices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final newInv = await ref
                            .read(openInvoicesProvider.notifier)
                            .createInvoiceForPatient(
                              patientId: widget.patientId,
                              patientName: widget.patientName,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Created Encounter Invoice #${newInv.id}'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                          Navigator.pop(context);
                          widget.onStartEncounter?.call(newInv.id);
                        }
                      },
                      icon: const Icon(Icons.add, size: 14, color: Colors.white),
                      label: const Text('New Encounter', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (patientInvoices.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textMuted),
                        SizedBox(height: 6),
                        Text('No billing encounters recorded yet for this patient.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text('Tap "New Encounter" above to start consultation & billing.', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else
                  ...patientInvoices.map((inv) {
                    final itemsDesc = inv.lineItems.isNotEmpty
                        ? inv.lineItems.map((li) => li.itemName).join(', ')
                        : 'Consultation encounter (no items dispensed yet)';
                    return _buildInvoiceTile(
                      inv.id,
                      itemsDesc,
                      '₱${inv.netPayable.toStringAsFixed(2)}',
                      inv.status.toUpperCase(),
                      isPaid: inv.isPaid,
                      hasDiscount: inv.hasSeniorOrPwdDiscount,
                    );
                  }),
              ],
            ),

            // Tab 2: Vaccine Schedule
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildScheduleTile('Hepatitis B — Dose 1 (Birth)', 'Administered at birth', 'Batch #HB-2026-04', true),
                _buildScheduleTile('BCG Tuberculosis Vaccine', 'Completed at 1 month', 'Batch #BCG-2026-01', true),
                _buildScheduleTile('Pentavalent (DTP-HepB-Hib) Dose 1', 'Completed at 6 weeks', 'Batch #PV-2026-11', true),
                _buildScheduleTile('MMR Pediatric Vaccine (Dose 1)', 'Scheduled · Due this month', 'To be allocated via FEFO at point-of-care', false),
                _buildScheduleTile('Inactivated Influenza (Seasonal)', 'Recommended · Approaching due', 'Awaiting clinic inventory allocation', false),
              ],
            ),

            // Tab 3: Reminders History
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildReminderTile('Vaccine MMR Booster Due Reminder', 'SMS delivered to ${widget.phone}', true),
                _buildReminderTile('Follow-Up Consultation Notification', 'Scheduled for next clinic week · SMS queued', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsCard() {
    final vitals = _latestVitals;
    final isHypertensive = vitals?.isHypertensive ?? false;
    final isFever = vitals?.isFever ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monitor_heart, color: AppColors.primary, size: 18),
                  SizedBox(width: 6),
                  Text('Triage & Vital Signs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _showRecordVitalsDialog,
                icon: const Icon(Icons.edit, size: 12),
                label: const Text('Update', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildVitalMetric('BP', vitals?.bloodPressure ?? '--/--', isAlert: isHypertensive),
              _buildVitalMetric('TEMP', '${vitals?.temperature.toStringAsFixed(1) ?? '--'}°C', isAlert: isFever),
              _buildVitalMetric('PULSE', '${vitals?.heartRate.toStringAsFixed(0) ?? '--'} bpm'),
              _buildVitalMetric('RESP', '${vitals?.respiratoryRate ?? '--'} cpm'),
              _buildVitalMetric('WEIGHT', '${vitals?.weightKg?.toStringAsFixed(1) ?? '--'} kg'),
            ],
          ),
          if (vitals?.chiefComplaint != null && vitals!.chiefComplaint!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Text('Chief Complaint: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Expanded(
                    child: Text(
                      vitals.chiefComplaint!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildVitalMetric(String label, String value, {bool isAlert = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isAlert ? AppColors.danger : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBox() {
    final hasAllergies = widget.allergies != null && widget.allergies!.isNotEmpty && widget.allergies != 'None recorded';

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
                  widget.patientName.isNotEmpty ? widget.patientName.substring(0, 1).toUpperCase() : 'P',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.patientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        if (widget.sex != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.sex!,
                              style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('DOB: ${widget.dob} · Contact: ${widget.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (widget.address != null && widget.address!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Address: ${widget.address}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                    if (widget.emergencyContact != null && widget.emergencyContact!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Emergency: ${widget.emergencyContact}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasAllergies) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ALLERGIES: ${widget.allergies}',
                      style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w700),
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

  Widget _buildInvoiceTile(
    String id,
    String desc,
    String amount,
    String status, {
    required bool isPaid,
    bool hasDiscount = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(id, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    if (hasDiscount) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('20% OFF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              isPaid ? StatusBadge.paid() : StatusBadge.open(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(String vaccine, String date, String batch, bool isDone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(isDone ? Icons.check_circle : Icons.schedule, color: isDone ? AppColors.success : AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vaccine, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$date · $batch', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          isDone ? StatusBadge.paid() : StatusBadge.open(),
        ],
      ),
    );
  }

  Widget _buildReminderTile(String title, String subtitle, bool isDelivered) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(isDelivered ? Icons.mark_email_read : Icons.hourglass_top, color: isDelivered ? AppColors.success : AppColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          isDelivered ? StatusBadge.paid() : StatusBadge.warning(text: 'Pending'),
        ],
      ),
    );
  }
}
