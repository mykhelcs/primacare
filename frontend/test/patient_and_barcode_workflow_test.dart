import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/data/repositories/patient_repository.dart';
import 'package:primacare/data/repositories/invoice_repository.dart';
import 'package:primacare/domain/models/inventory_item.dart';
import 'package:primacare/presentation/providers/invoice_provider.dart';
import 'package:primacare/presentation/screens/barcode_catalog_screen.dart';
import 'package:primacare/presentation/screens/barcode_scanner_screen.dart';

class _FailingDispenseInvoiceRepo extends InvoiceRepository {
  final bool shouldThrowException;
  int dispenseCallCount = 0;

  _FailingDispenseInvoiceRepo({this.shouldThrowException = false}) : super(client: null);

  @override
  Future<DispenseResult> dispenseItem({
    required String barcode,
    required String invoiceId,
    int quantity = 1,
  }) async {
    dispenseCallCount++;
    if (shouldThrowException) {
      throw Exception('PostgrestException: Concurrent row lock conflict or network drop');
    }
    return const DispenseResult(
      success: false,
      message: 'Insufficient unexpired stock available for this item.',
    );
  }
}

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

  group('Hardened Barcode Scanner & Asia/Manila Timezone QA Tests', () {
    test('Hardware Debounce: blocks duplicate barcode reads within 200ms cooldown window', () {
      final debouncer = BarcodeHardwareDebouncer(
        cooldown: const Duration(milliseconds: 250),
      );
      final t0 = DateTime(2026, 11, 9, 1, 0, 0, 0);

      // First scan at t=0ms is accepted
      expect(debouncer.shouldAcceptScan('4800016552011', now: t0), isTrue);

      // Duplicate scan of same item at t=120ms (< 200ms) is strictly rejected
      expect(
        debouncer.shouldAcceptScan(
          '4800016552011',
          now: t0.add(const Duration(milliseconds: 120)),
        ),
        isFalse,
      );

      // Duplicate scan of same item at t=200ms is still blocked within 250ms window
      expect(
        debouncer.shouldAcceptScan(
          '4800016552011',
          now: t0.add(const Duration(milliseconds: 200)),
        ),
        isFalse,
      );

      // Scan after cooldown (t=300ms) is accepted
      expect(
        debouncer.shouldAcceptScan(
          '4800016552011',
          now: t0.add(const Duration(milliseconds: 300)),
        ),
        isTrue,
      );
    });

    testWidgets('Graceful Failure: alerts nurse without false success when dispense_item fails or throws', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final failingRepo = _FailingDispenseInvoiceRepo(shouldThrowException: true);
      bool dispenseCallbackFired = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(failingRepo),
          ],
          child: MaterialApp(
            home: BarcodeScannerScreen(
              invoiceId: 'inv-1',
              onDispensed: () => dispenseCallbackFired = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap quick test chip to load Hep B Vaccine
      await tester.tap(find.text('Hep B Vaccine'));
      await tester.pumpAndSettle();

      expect(find.text('Hepatitis B Pediatric Vaccine'), findsOneWidget);

      // Tap Confirm Dispensation & Append to Bill
      final confirmBtn = find.text('Confirm Dispensation & Append to Bill');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Must NOT fire onDispensed (no false success state) and must alert nurse
      expect(dispenseCallbackFired, isFalse);
      expect(failingRepo.dispenseCallCount, 1);
      expect(find.textContaining('Dispensation failed'), findsWidgets);
    });

    test('Timezone Accuracy: Asia/Manila date boundary prevents off-by-one error between midnight and 8 AM', () {
      // 2026-11-08 18:30:00 UTC is 2026-11-09 02:30:00 AM in Asia/Manila (UTC+8)
      final utcMidnightWindow = DateTime.utc(2026, 11, 8, 18, 30, 0);
      final manilaDate = InventoryBatch.manilaToday(utcMidnightWindow);

      expect(manilaDate.year, 2026);
      expect(manilaDate.month, 11);
      expect(manilaDate.day, 9);
    });
  });
}
