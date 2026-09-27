import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:primacare/main.dart';

void main() {
  testWidgets('PrimaCareApp renders dashboard and branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PrimaCareApp(),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify app title / branding elements exist
    expect(find.textContaining('Good morning, Nurse Ana'), findsOneWidget);
    expect(find.text('Open invoices'), findsOneWidget);
    expect(find.text('Patients today'), findsOneWidget);
  });
}
