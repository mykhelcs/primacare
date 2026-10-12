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
  bool get canReceiveStock => this == UserRole.admin || this == UserRole.nurse;

  bool isTabAccessible(int tabIndex) {
    if (tabIndex == 10) return canViewFinancialReports;
    if (tabIndex == 7) return canReceiveStock;
    return true;
  }
}
