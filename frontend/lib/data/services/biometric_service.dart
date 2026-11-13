import 'package:flutter/foundation.dart';

enum BiometricType {
  fingerprint,
  faceId,
  iris,
  none,
}

/// Hardware adapter contract for native biometric authentication (e.g., local_auth).
abstract class BiometricAuthAdapter {
  Future<bool> authenticate({required String reason});
}

class BiometricService extends ChangeNotifier {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  bool _isBiometricSupported = true;
  bool _isEnrolled = true;
  BiometricType _availableType = BiometricType.fingerprint;
  BiometricAuthAdapter? _adapter;

  bool get isBiometricSupported => _isBiometricSupported;
  bool get isEnrolled => _isEnrolled;
  BiometricType get availableType => _availableType;
  bool get hasHardwareAdapter => _adapter != null;

  void setAdapter(BiometricAuthAdapter? adapter) {
    _adapter = adapter;
    notifyListeners();
  }

  String get biometricName {
    switch (_availableType) {
      case BiometricType.faceId:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Scanner';
      case BiometricType.none:
        return 'Screen PIN';
    }
  }

  void configureHardware({
    bool isSupported = true,
    bool isEnrolled = true,
    BiometricType type = BiometricType.fingerprint,
  }) {
    _isBiometricSupported = isSupported;
    _isEnrolled = isEnrolled;
    _availableType = type;
    notifyListeners();
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Scan your fingerprint or face to restore your clinical session',
  }) async {
    if (!_isBiometricSupported || !_isEnrolled) {
      return false;
    }

    if (_adapter != null) {
      return _adapter!.authenticate(reason: reason);
    }

    // Fail closed in release builds when no native biometric adapter is registered
    if (kReleaseMode) {
      return false;
    }

    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }
}
