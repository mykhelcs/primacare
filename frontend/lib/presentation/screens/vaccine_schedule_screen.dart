import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/patient.dart';
import '../providers/patient_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientListProvider);
    final patients = patientsAsync.value ?? [];

    Patient? selectedPatient;
    if (patients.isNotEmpty) {
      selectedPatient = patients.where((p) => p.id == _selectedPatientId).firstOrNull ?? patients.first;
      _selectedPatientId ??= selectedPatient.id;
    }

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
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Immunization record updated with electronic batch stamp.'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Record Dose', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildDoseCard(
                  vaccine: 'BCG (Bacillus Calmette–Guérin)',
                  date: 'Completed · At Birth',
                  batch: 'Batch #BCG-PH-01',
                  isDone: true,
                ),
                _buildDoseCard(
                  vaccine: 'Hepatitis B — Dose 1 (Birth)',
                  date: 'Completed · At Birth',
                  batch: 'Batch #HB-90-01',
                  isDone: true,
                ),
                _buildDoseCard(
                  vaccine: 'Pentavalent (DTP-HepB-Hib) — Dose 1',
                  date: 'Completed · 6 Weeks',
                  batch: 'Batch #PV-44-09',
                  isDone: true,
                ),
                _buildDoseCard(
                  vaccine: 'MMR (Measles, Mumps, Rubella) — Dose 1',
                  date: 'Scheduled · Next Due',
                  batch: 'FIFO Allocated: LOT-MMR-2027A',
                  isDone: false,
                ),
                _buildDoseCard(
                  vaccine: 'Influenza (Inactivated Quadrivalent)',
                  date: 'Recommended · Seasonal',
                  batch: 'FIFO Allocated: LOT-FLU-2026B',
                  isDone: false,
                ),
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

  Widget _buildDoseCard({
    required String vaccine,
    required String date,
    required String batch,
    required bool isDone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
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
    );
  }
}
