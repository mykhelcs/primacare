class Patient {
  final String id;
  final String fullName;
  final String? dateOfBirth;
  final String? contactNumber;
  final String? email;
  final DateTime? createdAt;

  const Patient({
    required this.id,
    required this.fullName,
    this.dateOfBirth,
    this.contactNumber,
    this.email,
    this.createdAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Unnamed Patient',
      dateOfBirth: json['date_of_birth'] as String?,
      contactNumber: json['contact_number'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (email != null) 'email': email,
    };
  }
}
