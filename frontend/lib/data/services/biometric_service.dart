import 'package:flutter/foundation.dart';

enum BiometricType {
  fingerprint,
  faceId,
  iris,
  none,
}

class BiometricService extends ChangeNotifier {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  bool _isBiometricSupported = true;
  bool _isEnrolled = true;
  BiometricType _availableType = BiometricType.fingerprint;

  bool get isBiometricSupported => _isBiometricSupported;
  bool get isEnrolled => _isEnrolled;
  BiometricType get availableType => _availableType;

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

    // Simulate fast native biometric sensor scan
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }
}
