import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/patient.dart';
import '../services/supabase_service.dart';

class PatientRepository {
  final SupabaseClient? _client;

  PatientRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  Future<List<Patient>> getPatients() async {
    if (_client == null) {
      return _mockPatients;
    }

    try {
      final response = await _client
          .from('patients')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((item) => Patient.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockPatients;
    }
  }

  Future<Patient> createPatient({
    required String fullName,
    String? dateOfBirth,
    String? contactNumber,
    String? email,
  }) async {
    if (_client == null) {
      final newPatient = Patient(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        dateOfBirth: dateOfBirth,
        contactNumber: contactNumber,
        email: email,
        createdAt: DateTime.now(),
      );
      _mockPatients.insert(0, newPatient);
      return newPatient;
    }

    try {
      final payload = <String, dynamic>{'full_name': fullName};
      if (dateOfBirth != null) payload['date_of_birth'] = dateOfBirth;
      if (contactNumber != null) payload['contact_number'] = contactNumber;
      if (email != null) payload['email'] = email;

      final response = await _client
          .from('patients')
          .insert(payload)
          .select()
          .single();
      return Patient.fromJson(response);
    } catch (_) {
      final fallback = Patient(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        dateOfBirth: dateOfBirth,
        contactNumber: contactNumber,
        email: email,
        createdAt: DateTime.now(),
      );
      _mockPatients.insert(0, fallback);
      return fallback;
    }
  }

  static final List<Patient> _mockPatients = [
    const Patient(
      id: 'p1',
      fullName: 'Juan Dela Cruz',
      dateOfBirth: '1990-05-15',
      contactNumber: '+63 917 123 4567',
      email: 'juan@example.ph',
    ),
    const Patient(
      id: 'p2',
      fullName: 'Maria Santos',
      dateOfBirth: '1985-11-02',
      contactNumber: '+63 928 987 6543',
      email: 'maria@example.ph',
    ),
    const Patient(
      id: 'p3',
      fullName: 'Roberto Lim',
      dateOfBirth: '1974-08-23',
      contactNumber: '+63 905 456 7890',
      email: 'roberto@example.ph',
    ),
    const Patient(
      id: 'p4',
      fullName: 'Elena Garcia',
      dateOfBirth: '1998-01-11',
      contactNumber: '+63 919 234 5678',
      email: 'elena@example.ph',
    ),
  ];
}
