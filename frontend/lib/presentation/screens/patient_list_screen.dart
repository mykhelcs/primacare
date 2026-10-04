import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/patient_provider.dart';
import '../providers/invoice_provider.dart';
import 'patient_profile_screen.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  final ValueChanged<String>? onPatientTapped;
  final ValueChanged<String>? onStartEncounter;

  const PatientListScreen({
    super.key,
    this.onPatientTapped,
    this.onStartEncounter,
  });

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddPatientDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final sexCtrl = TextEditingController(text: 'Female');
    final allergiesCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final emergencyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Clinical Patient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Maria Santos'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dobCtrl,
                      decoration: const InputDecoration(labelText: 'DOB (YYYY-MM-DD)', hintText: '1995-04-12'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: sexCtrl.text,
                      decoration: const InputDecoration(labelText: 'Sex'),
                      items: ['Female', 'Male', 'Other']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) sexCtrl.text = val;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Contact Phone', hintText: '+63 9XX XXX XXXX'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: allergiesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Known Allergies / Pre-existing',
                  hintText: 'e.g. Penicillin, Aspirin, Eggs',
                  prefixIcon: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emergencyCtrl,
                decoration: const InputDecoration(labelText: 'Emergency Contact & Relation', hintText: 'e.g. Juan (+63 917...)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Home / Clinic Address', hintText: 'e.g. Quezon City'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address', hintText: 'patient@example.ph'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                final newPat = await ref.read(patientListProvider.notifier).addPatient(
                      fullName: nameCtrl.text.trim(),
                      dateOfBirth: dobCtrl.text.trim().isNotEmpty ? dobCtrl.text.trim() : null,
                      contactNumber: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                      email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      sex: sexCtrl.text,
                      allergies: allergiesCtrl.text.trim().isNotEmpty ? allergiesCtrl.text.trim() : 'None recorded',
                      address: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
                      emergencyContact: emergencyCtrl.text.trim().isNotEmpty ? emergencyCtrl.text.trim() : null,
                    );
                if (ctx.mounted && mounted) {
                  Navigator.pop(ctx);
                  setState(() {
                    _searchController.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Registered ${newPat.fullName} in Clinical Records!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Register Patient'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientListProvider);
    final allPatients = patientsAsync.value ?? [];

    final filtered = allPatients.where((p) {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return p.fullName.toLowerCase().contains(q) ||
          (p.contactNumber?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Patients Directory',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.person_add, color: AppColors.primary),
              onPressed: _showAddPatientDialog,
              tooltip: 'New Patient',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(patientListProvider.notifier).refresh(),
        color: AppColors.primary,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search patient by name or phone...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  fillColor: AppColors.surface,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _searchController.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: patientsAsync.isLoading && allPatients.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 60),
                            Center(
                              child: Text(
                                'No patients found.\nPull down to refresh or register a patient.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final patient = filtered[index];
                            final initial = patient.fullName.isNotEmpty
                                ? patient.fullName[0].toUpperCase()
                                : 'P';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PatientProfileScreen(
                                          patientId: patient.id,
                                          patientName: patient.fullName,
                                          dob: patient.dateOfBirth ?? 'Not recorded',
                                          phone: patient.contactNumber ?? 'N/A',
                                          sex: patient.sex,
                                          allergies: patient.allergies,
                                          address: patient.address,
                                          emergencyContact: patient.emergencyContact,
                                          onStartEncounter: widget.onStartEncounter,
                                        ),
                                      ),
                                    );
                                    widget.onPatientTapped?.call(patient.id);
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          patient.fullName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (patient.sex != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            patient.sex!,
                                            style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 3),
                                      Text(
                                        'DOB: ${patient.dateOfBirth ?? 'N/A'} · ${patient.contactNumber ?? 'N/A'}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      if (patient.allergies != null && patient.allergies!.isNotEmpty && patient.allergies != 'None recorded') ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.danger),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Allergies: ${patient.allergies}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: ElevatedButton.icon(
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final inv = await ref
                                          .read(openInvoicesProvider.notifier)
                                          .createInvoiceForPatient(
                                            patientId: patient.id,
                                            patientName: patient.fullName,
                                          );
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Opened new Encounter Invoice #${inv.id} for ${patient.fullName}'),
                                            backgroundColor: AppColors.primary,
                                          ),
                                        );
                                        widget.onStartEncounter?.call(inv.id);
                                      }
                                    },
                                    icon: const Icon(Icons.receipt_long, size: 14, color: Colors.white),
                                    label: const Text('Bill', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
