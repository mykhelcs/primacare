import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:primacare/main.dart';
import 'package:primacare/presentation/screens/splash_screen.dart';
import 'package:primacare/presentation/screens/login_screen.dart';

void main() {
  testWidgets('PrimaCareApp launches with SplashScreen and gates to LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PrimaCareApp(),
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

    // Enter real clinic credentials
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.at(0), 'dr.santos@primacare.ph');
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
