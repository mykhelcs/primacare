import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/user_role.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  UserRole _currentRole = UserRole.nurse;
  UserRole get currentRole => _currentRole;

  DateTime _lastActivity = DateTime.now();
  Timer? _inactivityTimer;
  VoidCallback? onSessionExpired;

  static const int sessionTimeoutMinutes = 15;

  void setCurrentRole(UserRole role) {
    _currentRole = role;
  }

  void startSessionWatcher({VoidCallback? onTimeout}) {
    onSessionExpired = onTimeout;
    _recordActivity();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final inactiveDuration = DateTime.now().difference(_lastActivity);
      if (inactiveDuration.inMinutes >= sessionTimeoutMinutes) {
        _inactivityTimer?.cancel();
        onSessionExpired?.call();
      }
    });
  }

  void recordUserInteraction() {
    _recordActivity();
  }

  void _recordActivity() {
    _lastActivity = DateTime.now();
  }

  void dispose() {
    _inactivityTimer?.cancel();
  }
}
