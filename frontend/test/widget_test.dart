import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:primacare/main.dart';
import 'package:primacare/data/repositories/auth_repository.dart';
import 'package:primacare/domain/models/staff_profile.dart';
import 'package:primacare/domain/models/user_role.dart';
import 'package:primacare/presentation/providers/auth_provider.dart';
import 'package:primacare/presentation/screens/splash_screen.dart';
import 'package:primacare/presentation/screens/login_screen.dart';

class _TestAuthRepository extends AuthRepository {
  StaffProfile? _profile;

  @override
  bool get isAuthenticated => _profile != null;

  @override
  StaffProfile? get activeProfile => _profile;

  @override
  void switchClinic(ClinicTenant newClinic) {
    if (_profile != null) {
      _profile = _profile!.copyWith(clinic: newClinic);
    }
  }

  @override
  Future<StaffProfile> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _profile = StaffProfile(
      id: 'test-doc-1',
      email: email.trim().toLowerCase(),
      fullName: 'Dr. Alejandro Cruz, MD',
      role: UserRole.doctor,
      clinic: ClinicTenant.centralBranch(),
    );
    return _profile!;
  }

  @override
  Future<void> signOut() async {
    _profile = null;
  }
}

void main() {
  testWidgets('PrimaCareApp fails closed on LoginScreen when Supabase is unconfigured', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PrimaCareApp(),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'doctor@primacare.ph');
    await tester.enterText(textFields.at(1), 'password123');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In to Clinic'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('not configured'), findsOneWidget);
  });

  testWidgets('PrimaCareApp launches with SplashScreen, gates to LoginScreen, and unlocks on valid auth', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_TestAuthRepository()),
        ],
        child: const PrimaCareApp(),
      ),
    );

    // Initial pump shows SplashScreen
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('PrimaCare'), findsOneWidget);

    // Fast-forward past splash duration (1.5 seconds)
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Now user must be presented with the mandatory LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Staff Authentication'), findsOneWidget);
    expect(find.text('Sign In to Clinic'), findsOneWidget);

    // Enter clinic credentials
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.at(0), 'doctor@primacare.ph');
    await tester.enterText(textFields.at(1), 'password123');

    // Tap Sign In button
    final signInBtn = find.widgetWithText(ElevatedButton, 'Sign In to Clinic');
    expect(signInBtn, findsOneWidget);
    await tester.tap(signInBtn);

    // Settle async login
    await tester.pumpAndSettle();

    // Now clinical operations shell is unlocked and rendered
    expect(find.textContaining('Hello, Dr.'), findsOneWidget);
    expect(find.text('Unpaid Receivables'), findsOneWidget);
    expect(find.text('Total Patients'), findsOneWidget);
  });
}
