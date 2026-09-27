import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/services/supabase_service.dart';
import 'presentation/screens/main_shell_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env configuration
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('.env load skipped: $e');
  }

  // Safely initialize Supabase if keys are provided
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization deferred: $e');
  }

  runApp(
    const ProviderScope(
      child: PrimaCareApp(),
    ),
  );
}

class PrimaCareApp extends StatelessWidget {
  const PrimaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrimaCare Smart Clinic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainShellScreen(),
    );
  }
}
