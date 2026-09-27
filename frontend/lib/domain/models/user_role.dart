enum UserRole {
  admin,
  nurse,
  doctor;

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'doctor':
        return UserRole.doctor;
      case 'nurse':
      default:
        return UserRole.nurse;
    }
  }

  bool get canManageInventory => this == UserRole.admin || this == UserRole.nurse;
  bool get canViewFinancialReports => this == UserRole.admin;
  bool get canDispense => this == UserRole.nurse || this == UserRole.admin;
}
