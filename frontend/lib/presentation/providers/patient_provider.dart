import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/patient_repository.dart';
import '../../domain/models/patient.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository();
});

final patientListProvider = AsyncNotifierProvider<PatientListNotifier, List<Patient>>(
  PatientListNotifier.new,
);

class PatientListNotifier extends AsyncNotifier<List<Patient>> {
  @override
  Future<List<Patient>> build() async {
    final repo = ref.read(patientRepositoryProvider);
    return repo.getPatients();
  }

  Future<void> addPatient({
    required String fullName,
    String? dateOfBirth,
    String? contactNumber,
    String? email,
  }) async {
    final repo = ref.read(patientRepositoryProvider);
    final newPatient = await repo.createPatient(
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      contactNumber: contactNumber,
      email: email,
    );
    state = AsyncData([newPatient, ...state.value ?? []]);
  }
}
