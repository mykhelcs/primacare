class Patient {
  final String id;
  final String fullName;
  final String? dateOfBirth;
  final String? contactNumber;
  final String? email;
  final String? sex;
  final String? allergies;
  final String? address;
  final String? emergencyContact;
  final DateTime? createdAt;

  const Patient({
    required this.id,
    required this.fullName,
    this.dateOfBirth,
    this.contactNumber,
    this.email,
    this.sex,
    this.allergies,
    this.address,
    this.emergencyContact,
    this.createdAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Unnamed Patient',
      dateOfBirth: json['date_of_birth'] as String?,
      contactNumber: json['contact_number'] as String?,
      email: json['email'] as String?,
      sex: json['sex'] as String?,
      allergies: json['allergies'] as String?,
      address: json['address'] as String?,
      emergencyContact: json['emergency_contact'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Patient copyWith({
    String? id,
    String? fullName,
    String? dateOfBirth,
    String? contactNumber,
    String? email,
    String? sex,
    String? allergies,
    String? address,
    String? emergencyContact,
    DateTime? createdAt,
  }) {
    return Patient(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      sex: sex ?? this.sex,
      allergies: allergies ?? this.allergies,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (email != null) 'email': email,
      if (sex != null) 'sex': sex,
      if (allergies != null) 'allergies': allergies,
      if (address != null) 'address': address,
      if (emergencyContact != null) 'emergency_contact': emergencyContact,
    };
  }
}
