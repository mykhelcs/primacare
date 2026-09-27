import 'user_role.dart';

class ClinicTenant {
  final String id;
  final String name;
  final String code;
  final String address;
  final String contactNumber;
  final String tinNumber;

  const ClinicTenant({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.contactNumber,
    required this.tinNumber,
  });

  factory ClinicTenant.fromMap(Map<String, dynamic> map) {
    return ClinicTenant(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'PrimaCare Clinic',
      code: map['code']?.toString() ?? 'PC-MAIN',
      address: map['address']?.toString() ?? 'Metro Manila, PH',
      contactNumber: map['contact_number']?.toString() ?? '+63 2 8123 4567',
      tinNumber: map['tin_number']?.toString() ?? '123-456-789-000',
    );
  }

  static ClinicTenant centralBranch() {
    return const ClinicTenant(
      id: '00000000-0000-0000-0000-000000000001',
      name: 'PrimaCare Central Clinic',
      code: 'PC-CENTRAL',
      address: '123 Medical Center Blvd, Metro Manila',
      contactNumber: '+63 2 8123 4567',
      tinNumber: '123-456-789-000',
    );
  }

  static ClinicTenant northBranch() {
    return const ClinicTenant(
      id: '00000000-0000-0000-0000-000000000002',
      name: 'PrimaCare North Branch',
      code: 'PC-NORTH',
      address: '45 North Ave, Quezon City',
      contactNumber: '+63 2 8987 6543',
      tinNumber: '123-456-789-001',
    );
  }
}

class StaffProfile {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final ClinicTenant clinic;

  const StaffProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.clinic,
  });

  String get clinicId => clinic.id;

  StaffProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    ClinicTenant? clinic,
  }) {
    return StaffProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      clinic: clinic ?? this.clinic,
    );
  }

  factory StaffProfile.fromMap(Map<String, dynamic> map) {
    return StaffProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? map['fullName']?.toString() ?? 'Clinical Staff',
      role: UserRole.fromString(map['role']?.toString()),
      clinic: map['clinic'] != null
          ? ClinicTenant.fromMap(Map<String, dynamic>.from(map['clinic']))
          : ClinicTenant.centralBranch(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'clinic_id': clinic.id,
    };
  }

  static StaffProfile mockNurse() {
    return StaffProfile(
      id: 'staff-nurse-1',
      email: 'nurse@primacare.ph',
      fullName: 'Nurse Sarah Jenkins, RN',
      role: UserRole.nurse,
      clinic: ClinicTenant.centralBranch(),
    );
  }

  static StaffProfile mockDoctor() {
    return StaffProfile(
      id: 'staff-doc-1',
      email: 'doctor@primacare.ph',
      fullName: 'Dr. Alejandro Cruz, MD',
      role: UserRole.doctor,
      clinic: ClinicTenant.centralBranch(),
    );
  }

  static StaffProfile mockAdmin() {
    return StaffProfile(
      id: 'staff-admin-1',
      email: 'admin@primacare.ph',
      fullName: 'Admin Mark Villareal',
      role: UserRole.admin,
      clinic: ClinicTenant.centralBranch(),
    );
  }
}
