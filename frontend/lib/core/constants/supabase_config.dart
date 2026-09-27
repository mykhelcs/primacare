import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static const String projectRef = 'aepfwuoywxunjgxutfff';
  static const String defaultUrl = 'https://aepfwuoywxunjgxutfff.supabase.co';
  
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment('SUPABASE_URL', defaultValue: defaultUrl);

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static const String dbHost = 'aws-0-ap-northeast-2.pooler.supabase.com';
  static const int dbPort = 5432;
  static const String dbName = 'postgres';
  static const String dbUser = 'postgres.aepfwuoywxunjgxutfff';
}
