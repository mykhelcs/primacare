import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/staff_profile.dart';
import '../../domain/models/user_role.dart';
import '../services/supabase_service.dart';

class AuthRepository {
  final SupabaseClient? _client;
  StaffProfile? _activeProfile;

  AuthRepository({
    SupabaseClient? client,
  }) : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  User? get currentUser => _client?.auth.currentUser;

  bool get isAuthenticated => _client?.auth.currentUser != null;

  StaffProfile? get activeProfile =>
      _client?.auth.currentUser != null ? _activeProfile : null;

  void switchClinic(ClinicTenant newClinic) {
    if (_activeProfile != null) {
      _activeProfile = _activeProfile!.copyWith(clinic: newClinic);
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

    final client = _client;
    if (client == null) {
      throw StateError(
        'Clinical authentication server is not configured. Please provide SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    final response = await client.auth.signInWithPassword(
      email: cleanEmail,
      password: cleanPassword,
    );

    final user = response.user;
    if (user == null) {
      throw StateError('Authentication failed: No user returned by clinical identity server.');
    }

    String? dbRole;
    String? dbFullName;
    try {
      final userRow = await client
          .from('users')
          .select('role, full_name')
          .eq('id', user.id)
          .maybeSingle();
      if (userRow != null) {
        dbRole = userRow['role'] as String?;
        dbFullName = userRow['full_name'] as String?;
      }
    } catch (_) {}

    final profile = StaffProfile(
      id: user.id,
      email: user.email ?? cleanEmail,
      fullName: dbFullName ??
          user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String? ??
          cleanEmail.split('@').first.toUpperCase(),
      role: UserRole.fromString(
        dbRole ?? (user.userMetadata?['role'] as String?),
      ),
      clinic: ClinicTenant.centralBranch(),
    );
    _activeProfile = profile;
    return profile;
  }

  Future<void> signOut() async {
    _activeProfile = null;
    if (_client != null) {
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
  }
}
