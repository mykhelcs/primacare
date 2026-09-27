import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/biometric_service.dart';

class BiometricUnlockDialog extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onSignOut;

  const BiometricUnlockDialog({
    super.key,
    required this.onUnlocked,
    required this.onSignOut,
  });

  @override
  State<BiometricUnlockDialog> createState() => _BiometricUnlockDialogState();
}

class _BiometricUnlockDialogState extends State<BiometricUnlockDialog> {
  final _bioService = BiometricService();
  bool _isAuthenticating = false;
  String? _errorMessage;

  void _triggerBiometric() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final success = await _bioService.authenticateWithBiometrics();
    if (mounted) {
      setState(() => _isAuthenticating = false);
      if (success) {
        widget.onUnlocked();
      } else {
        setState(() => _errorMessage = 'Biometric scan was cancelled or unrecognized.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bioName = _bioService.biometricName;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.fingerprint,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Clinical Session Paused',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Due to 15 minutes of inactivity, please scan your $bioName to resume your session without re-typing credentials.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isAuthenticating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.fingerprint),
                  label: Text('Unlock with $bioName'),
                  onPressed: _isAuthenticating ? null : _triggerBiometric,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onSignOut,
                child: const Text(
                  'Switch Staff Account / Sign Out',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
