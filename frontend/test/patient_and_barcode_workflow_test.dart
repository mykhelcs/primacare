import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/data/repositories/patient_repository.dart';
import 'package:primacare/data/repositories/invoice_repository.dart';
import 'package:primacare/presentation/screens/barcode_catalog_screen.dart';

void main() {
  group('Patient Repository & Instant Sync Tests', () {
    test('createPatient persists patient locally and in getPatients() list', () async {
      final repo = PatientRepository(client: null);

      final newPatient = await repo.createPatient(
        fullName: 'Test Patient Juan',
        dateOfBirth: '1992-04-10',
        contactNumber: '+63 917 999 8888',
        email: 'juan.test@example.ph',
        sex: 'Male',
        allergies: 'Amoxicillin',
        address: 'BGC, Taguig City',
        emergencyContact: '+63 917 111 2222 (Sister)',
      );

      expect(newPatient.fullName, 'Test Patient Juan');
      expect(newPatient.sex, 'Male');
      expect(newPatient.allergies, 'Amoxicillin');
      expect(newPatient.address, 'BGC, Taguig City');

      final list = await repo.getPatients();
      expect(list.any((p) => p.fullName == 'Test Patient Juan'), isTrue);
    });
  });

  group('Invoice Repository Mock UUID Safety Tests', () {
    test('getInvoiceById("inv-1") safely resolves without throwing UUID parse error', () async {
      final repo = InvoiceRepository(client: null);
      final invoice = await repo.getInvoiceById('inv-1');
      expect(invoice, isNotNull);
      expect(invoice!.id, 'inv-1');
    });
  });

  group('Barcode & QR Catalog Widget Tests', () {
    testWidgets('Renders Barcode Catalog with categories and product items', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BarcodeCatalogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Barcodes & QR Catalog'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Vaccines'), findsOneWidget);
      expect(find.text('Pharmaceuticals'), findsOneWidget);

      // Verify actions
      expect(find.byTooltip('Export / Print Sheet'), findsOneWidget);
      expect(find.byTooltip('Open Scanner'), findsOneWidget);
    });
  });
}
