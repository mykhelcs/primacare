import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/patient_repository.dart';
import '../../domain/models/patient.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository();
});

final patientListProvider =
    AsyncNotifierProvider<PatientListNotifier, List<Patient>>(
  PatientListNotifier.new,
);

class PatientListNotifier extends AsyncNotifier<List<Patient>> {
  @override
  Future<List<Patient>> build() async {
    final repo = ref.read(patientRepositoryProvider);
    return repo.getPatients();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repo = ref.read(patientRepositoryProvider);
    state = AsyncData(await repo.getPatients());
  }

  Future<Patient> addPatient({
    required String fullName,
    String? dateOfBirth,
    String? contactNumber,
    String? email,
    String? sex,
    String? allergies,
    String? address,
    String? emergencyContact,
  }) async {
    final repo = ref.read(patientRepositoryProvider);
    final newPatient = await repo.createPatient(
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      contactNumber: contactNumber,
      email: email,
      sex: sex,
      allergies: allergies,
      address: address,
      emergencyContact: emergencyContact,
    );
    // Immediately emit new state for instant UI update without waiting
    final current = state.value ?? [];
    state = AsyncData([newPatient, ...current.where((p) => p.id != newPatient.id)]);
    
    // Background sync
    final refreshed = await repo.getPatients();
    state = AsyncData(refreshed);
    return newPatient;
  }
}
