import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/patient.dart';
import '../services/supabase_service.dart';

class PatientRepository {
  final SupabaseClient? _client;

  PatientRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  static final List<Patient> _localCreatedPatients = [];

  Future<List<Patient>> getPatients() async {
    if (_client == null) {
      return [..._localCreatedPatients, ..._mockPatients];
    }

    try {
      final response = await _client
          .from('patients')
          .select()
          .order('created_at', ascending: false);
      final remoteList = (response as List)
          .map((item) => Patient.fromJson(item as Map<String, dynamic>))
          .toList();

      final remoteIds = remoteList.map((p) => p.id).toSet();
      final remoteNames = remoteList.map((p) => p.fullName.toLowerCase().trim()).toSet();

      final unmerged = _localCreatedPatients.where(
        (p) => !remoteIds.contains(p.id) && !remoteNames.contains(p.fullName.toLowerCase().trim()),
      );
      return [...unmerged, ...remoteList];
    } catch (_) {
      return [..._localCreatedPatients, ..._mockPatients];
    }
  }

  Future<Patient> createPatient({
    required String fullName,
    String? dateOfBirth,
    String? contactNumber,
    String? email,
    String? sex,
    String? allergies,
    String? address,
    String? emergencyContact,
  }) async {
    final corePayload = <String, dynamic>{'full_name': fullName};
    if (dateOfBirth != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateOfBirth.trim())) {
      corePayload['date_of_birth'] = dateOfBirth.trim();
    }
    if (contactNumber != null && contactNumber.trim().isNotEmpty) {
      corePayload['contact_number'] = contactNumber.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      corePayload['email'] = email.trim();
    }

    if (_client != null) {
      try {
        final fullPayload = Map<String, dynamic>.from(corePayload);
        if (sex != null && sex.trim().isNotEmpty) fullPayload['sex'] = sex.trim();
        if (allergies != null && allergies.trim().isNotEmpty) fullPayload['allergies'] = allergies.trim();
        if (address != null && address.trim().isNotEmpty) fullPayload['address'] = address.trim();
        if (emergencyContact != null && emergencyContact.trim().isNotEmpty) {
          fullPayload['emergency_contact'] = emergencyContact.trim();
        }

        final response = await _client
            .from('patients')
            .insert(fullPayload)
            .select()
            .single();
        final created = Patient.fromJson(response);
        _localCreatedPatients.insert(0, created);
        return created;
      } catch (_) {
        try {
          final coreResponse = await _client
              .from('patients')
              .insert(corePayload)
              .select()
              .single();
          final created = Patient.fromJson(coreResponse).copyWith(
            sex: sex,
            allergies: allergies,
            address: address,
            emergencyContact: emergencyContact,
          );
          _localCreatedPatients.insert(0, created);
          return created;
        } catch (_) {}
      }
    }

    final fallback = Patient(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      contactNumber: contactNumber,
      email: email,
      sex: sex,
      allergies: allergies,
      address: address,
      emergencyContact: emergencyContact,
      createdAt: DateTime.now(),
    );
    _localCreatedPatients.insert(0, fallback);
    return fallback;
  }

  static final List<Patient> _mockPatients = [
    const Patient(
      id: 'p1',
      fullName: 'Juan Dela Cruz',
      dateOfBirth: '1990-05-15',
      contactNumber: '+63 917 123 4567',
      email: 'juan@example.ph',
      sex: 'Male',
      allergies: 'None recorded',
      address: 'Block 4 Lot 2, Central Village, Quezon City',
      emergencyContact: '+63 917 555 1111 (Wife: Maria)',
    ),
    const Patient(
      id: 'p2',
      fullName: 'Maria Santos',
      dateOfBirth: '1985-11-02',
      contactNumber: '+63 928 987 6543',
      email: 'maria@example.ph',
      sex: 'Female',
      allergies: 'Penicillin, Amoxicillin',
      address: '15 Kalayaan Ave, Makati City',
      emergencyContact: '+63 928 333 4444 (Mother)',
    ),
    const Patient(
      id: 'p3',
      fullName: 'Roberto Lim',
      dateOfBirth: '1974-08-23',
      contactNumber: '+63 905 456 7890',
      email: 'roberto@example.ph',
      sex: 'Male',
      allergies: 'Aspirin, Ibuprofen',
      address: '77 Commonwealth Ave, Quezon City',
      emergencyContact: '+63 905 111 2222 (Son: John)',
    ),
    const Patient(
      id: 'p4',
      fullName: 'Elena Garcia',
      dateOfBirth: '1998-01-11',
      contactNumber: '+63 919 234 5678',
      email: 'elena@example.ph',
      sex: 'Female',
      allergies: 'Sulfa drugs',
      address: 'Unit 12B Horizon Towers, Taguig',
      emergencyContact: '+63 919 777 8888 (Sister: Anna)',
    ),
  ];
}
