import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'data/services/supabase_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'presentation/screens/splash_screen.dart';

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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _isSplashFinished = false;

  @override
  Widget build(BuildContext context) {
    if (!_isSplashFinished) {
      return SplashScreen(
        onInitializationComplete: () {
          setState(() => _isSplashFinished = true);
        },
      );
    }

    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (!isAuthenticated) {
      return const LoginScreen();
    }

    return const MainShellScreen();
  }
}
