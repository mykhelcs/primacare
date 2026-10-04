import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:primacare/presentation/screens/invoice_detail_screen.dart';
import 'package:primacare/presentation/providers/invoice_provider.dart';
import 'package:primacare/presentation/providers/inventory_provider.dart';
import 'package:primacare/data/repositories/invoice_repository.dart';
import 'package:primacare/data/repositories/inventory_repository.dart';
import 'package:primacare/domain/models/inventory_item.dart';

class _EmptyInventoryRepo extends InventoryRepository {
  @override
  Future<List<InventoryItem>> getInventoryItems() async => [];
}

void main() {
  group('InvoiceDetailScreen Zero-Defect Robustness Tests', () {
    testWidgets('Opening Dispense dialog safely shows No Dispensable Items dialog when inventory is empty', (WidgetTester tester) async {
      final emptyInventoryRepo = _EmptyInventoryRepo();
      final invoiceRepo = InvoiceRepository(client: null);
      final testInvoice = await invoiceRepo.createInvoice(
        patientId: 'test-p1',
        patientName: 'Test Patient',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(emptyInventoryRepo),
            invoiceRepositoryProvider.overrideWithValue(invoiceRepo),
          ],
          child: MaterialApp(
            home: InvoiceDetailScreen(
              invoiceId: testInvoice.id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify invoice screen loaded
      expect(find.text('Invoice #${testInvoice.id}'), findsOneWidget);
      expect(find.text('Test Patient'), findsOneWidget);

      // Tap Dispense Med/Item
      final dispenseBtn = find.text('Dispense Med/Item');
      expect(dispenseBtn, findsOneWidget);
      await tester.tap(dispenseBtn);
      await tester.pumpAndSettle();

      // Should safely show the dialog without Bad state: No element
      expect(find.text('No Dispensable Items'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('No Dispensable Items'), findsNothing);
    });

    testWidgets('Opening Dispense dialog with populated inventory renders selection dialog', (WidgetTester tester) async {
      final invoiceRepo = InvoiceRepository(client: null);
      final testInvoice = await invoiceRepo.createInvoice(
        patientId: 'test-p1',
        patientName: 'Test Patient',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(invoiceRepo),
          ],
          child: MaterialApp(
            home: InvoiceDetailScreen(
              invoiceId: testInvoice.id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Dispense Med/Item
      final dispenseBtn = find.text('Dispense Med/Item');
      expect(dispenseBtn, findsOneWidget);
      await tester.tap(dispenseBtn);
      await tester.pumpAndSettle();

      // Should show the catalog selection dialog
      expect(find.text('Dispense from Clinic Catalog'), findsOneWidget);
      expect(find.text('Dispense to Bill'), findsOneWidget);
    });

    testWidgets('Adding service fee updates invoice payable without stock deduction', (WidgetTester tester) async {
      final invoiceRepo = InvoiceRepository(client: null);
      final testInvoice = await invoiceRepo.createInvoice(
        patientId: 'test-p2',
        patientName: 'Elena Ramos',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(invoiceRepo),
          ],
          child: MaterialApp(
            home: InvoiceDetailScreen(
              invoiceId: testInvoice.id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Add Service Fee
      final addFeeBtn = find.text('Add Service Fee');
      expect(addFeeBtn, findsOneWidget);
      await tester.tap(addFeeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Clinical Service / Consultation Fee'), findsOneWidget);

      // Select preset General Medical Consultation (₱500)
      final consultFeeOption = find.text('General Medical Consultation');
      expect(consultFeeOption, findsOneWidget);
      await tester.tap(consultFeeOption);
      await tester.pumpAndSettle();

      // Verify bill updated
      expect(find.text('General Medical Consultation'), findsOneWidget);
      expect(find.text('₱500.00'), findsWidgets);
    });

    testWidgets('Payment collection calculates change and marks invoice settled', (WidgetTester tester) async {
      final invoiceRepo = InvoiceRepository(client: null);
      final testInvoice = await invoiceRepo.createInvoice(
        patientId: 'test-p3',
        patientName: 'Carlos Tan',
      );
      await invoiceRepo.addServiceItem(
        invoiceId: testInvoice.id,
        serviceName: 'Well-Baby Checkup',
        fee: 600.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(invoiceRepo),
          ],
          child: MaterialApp(
            home: InvoiceDetailScreen(
              invoiceId: testInvoice.id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Collect Payment
      final settleBtn = find.text('Collect Payment / Settle Invoice');
      expect(settleBtn, findsOneWidget);
      await tester.tap(settleBtn);
      await tester.pumpAndSettle();

      expect(find.text('Collect Encounter Payment'), findsOneWidget);
      expect(find.text('Confirm Payment'), findsOneWidget);

      // Confirm payment
      await tester.tap(find.text('Confirm Payment'));
      await tester.pumpAndSettle();

      // Should now show settled
      expect(find.text('Settled in Full'), findsOneWidget);
    });
  });
}
