import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/supabase_config.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static bool get isInitialized => _client != null;

  static SupabaseClient get client {
    if (_client == null) {
      throw StateError(
        'SupabaseService has not been initialized. Please provide SUPABASE_ANON_KEY.',
      );
    }
    return _client!;
  }

  static Future<void> initialize({
    String? url,
    String? anonKey,
  }) async {
    final finalUrl = url ?? SupabaseConfig.supabaseUrl;
    final finalKey = anonKey ?? SupabaseConfig.supabaseAnonKey;

    if (finalKey.isEmpty) {
      // In development or test when key is not yet set
      return;
    }

    final supabase = await Supabase.initialize(
      url: finalUrl,
      publishableKey: finalKey,
    );
    _client = supabase.client;
  }
}
