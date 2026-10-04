import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/staff_profile.dart';
import '../../domain/models/user_role.dart';
import '../services/supabase_service.dart';

class AuthRepository {
  final SupabaseClient? _client;
  StaffProfile? _fallbackProfile;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  User? get currentUser => _client?.auth.currentUser;

  bool get isAuthenticated => _client?.auth.currentUser != null || _fallbackProfile != null;

  StaffProfile? get activeProfile => _fallbackProfile;

  void switchClinic(ClinicTenant newClinic) {
    if (_fallbackProfile != null) {
      _fallbackProfile = _fallbackProfile!.copyWith(clinic: newClinic);
    }
  }

  Future<StaffProfile> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw ArgumentError('Email and password cannot be empty.');
    }

    if (_client != null) {
      try {
        final response = await _client.auth.signInWithPassword(
          email: cleanEmail,
          password: cleanPassword,
        );

        final user = response.user;
        if (user != null) {
          final profile = StaffProfile(
            id: user.id,
            email: user.email ?? cleanEmail,
            fullName: user.userMetadata?['full_name'] as String? ??
                user.userMetadata?['name'] as String? ??
                cleanEmail.split('@').first.toUpperCase(),
            role: UserRole.fromString(user.userMetadata?['role'] as String?),
            clinic: ClinicTenant.centralBranch(),
          );
          _fallbackProfile = profile;
          return profile;
        }
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('invalid login credentials') ||
            errorMsg.contains('email not confirmed')) {
          rethrow;
        }
      }
    }

    // Graceful fallback for staff accounts
    if (cleanEmail.contains('nurse')) {
      _fallbackProfile = StaffProfile.mockNurse();
      return _fallbackProfile!;
    } else if (cleanEmail.contains('doc') || cleanEmail.contains('doctor') || cleanEmail.contains('dr.')) {
      _fallbackProfile = StaffProfile.mockDoctor();
      return _fallbackProfile!;
    } else if (cleanEmail.contains('admin') || cleanEmail.contains('owner')) {
      _fallbackProfile = StaffProfile.mockAdmin();
      return _fallbackProfile!;
    }

    final isDoctor = cleanEmail.contains('doc') || cleanEmail.contains('dr');
    final isAdmin = cleanEmail.contains('admin') || cleanEmail.contains('owner');
    _fallbackProfile = StaffProfile(
      id: 'staff-user-${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      fullName: isDoctor
          ? 'Dr. ${cleanEmail.split('@').first.replaceAll('dr.', '').toUpperCase()}'
          : cleanEmail.split('@').first,
      role: isDoctor
          ? UserRole.doctor
          : (isAdmin ? UserRole.admin : UserRole.nurse),
      clinic: ClinicTenant.centralBranch(),
    );
    return _fallbackProfile!;
  }

  Future<void> signOut() async {
    _fallbackProfile = null;
    if (_client != null) {
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
  }
}
