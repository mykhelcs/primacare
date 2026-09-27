import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthRepository {
  final SupabaseClient? _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  User? get currentUser => _client?.auth.currentUser;

  Future<AuthResponse?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (_client == null) {
      return null;
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_client != null) {
      await _client.auth.signOut();
    }
  }
}
