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

    // Tap quick demo login as Nurse
    final nurseBtn = find.text('👩‍⚕️ Nurse');
    expect(nurseBtn, findsOneWidget);
    await tester.tap(nurseBtn);

    // Settle async login
    await tester.pumpAndSettle();

    // Now clinical operations shell is unlocked and rendered
    expect(find.textContaining('Hello, Nurse Sarah Jenkins'), findsOneWidget);
    expect(find.text('Open invoices'), findsOneWidget);
    expect(find.text('Total Patients'), findsOneWidget);
  });
}
