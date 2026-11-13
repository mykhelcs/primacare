import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/data/repositories/auth_repository.dart';
import 'package:primacare/data/repositories/inventory_repository.dart';
import 'package:primacare/data/repositories/invoice_repository.dart';
import 'package:primacare/data/services/biometric_service.dart';
import 'package:primacare/data/services/offline_sync_service.dart';
import 'package:primacare/data/services/thermal_printer_service.dart';
import 'package:primacare/domain/models/inventory_item.dart';
import 'package:primacare/domain/models/invoice.dart';
import 'package:primacare/domain/models/patient.dart';
import 'package:primacare/domain/models/staff_profile.dart';
import 'package:primacare/presentation/providers/inventory_provider.dart';
import 'package:primacare/presentation/providers/invoice_provider.dart';
import 'package:primacare/presentation/providers/patient_provider.dart';
import 'package:primacare/presentation/screens/vaccine_schedule_screen.dart';

class _InMemoryQueueStorage implements OfflineQueueStorage {
  String? _raw;

  @override
  Future<String?> read() async => _raw;

  @override
  Future<void> write(String data) async {
    _raw = data;
  }

  @override
  Future<void> clear() async {
    _raw = null;
  }
}

class _FailingBiometricAdapter implements BiometricAuthAdapter {
  @override
  Future<bool> authenticate({required String reason}) async => false;
}

class _DisconnectedPrinterAdapter implements EscPosPrinterAdapter {
  @override
  Future<bool> sendRawText({
    required String deviceName,
    required String formattedText,
  }) async =>
      false;
}

class _ZeroStockVaccineInventoryRepo extends InventoryRepository {
  _ZeroStockVaccineInventoryRepo() : super(client: null);

  @override
  Future<List<InventoryItem>> getInventoryItems() async => const [
        InventoryItem(
          id: 'vac-zero-1',
          name: 'Hepatitis B Pediatric Vaccine',
          barcode: '4800016552011',
          unit: 'vial',
          unitCost: 450.0,
          category: 'Vaccines',
          reorderLevel: 10,
          totalStock: 0,
        ),
      ];

  @override
  Future<InventoryItem?> getItemByBarcode(String barcode) async {
    if (barcode == '4800016552011') {
      return (await getInventoryItems()).first;
    }
    return null;
  }
}

void main() {
  group('Priority 1 QA Tests: Live Supabase Schema & Integrity', () {
    test('Invoice.fromJson parses Supabase invoice_line_items, nested patients, and payment audit fields', () {
      final supabaseRow = <String, dynamic>{
        'id': '11111111-1111-1111-1111-111111111111',
        'patient_id': '22222222-2222-2222-2222-222222222222',
        'patients': {'full_name': 'Maria Clara'},
        'status': 'paid',
        'total_amount': 950.0,
        'discount_type': 'senior',
        'discount_percentage': 20.0,
        'discount_id_number': 'OSCA-4455',
        'payment_method': 'GCash',
        'paid_at': '2026-11-13T06:00:00.000Z',
        'created_at': '2026-11-13T05:30:00.000Z',
        'invoice_line_items': [
          {
            'id': '33333333-3333-3333-3333-333333333333',
            'invoice_id': '11111111-1111-1111-1111-111111111111',
            'inventory_batch_id': '44444444-4444-4444-4444-444444444444',
            'item_name': 'Hepatitis B Pediatric Vaccine',
            'quantity': 1,
            'unit_cost': 450.0,
          },
          {
            'id': '55555555-5555-5555-5555-555555555555',
            'invoice_id': '11111111-1111-1111-1111-111111111111',
            'inventory_batch_id': null,
            'item_name': 'General Medical Consultation',
            'quantity': 1,
            'unit_cost': 500.0,
          },
        ],
      };

      final invoice = Invoice.fromJson(supabaseRow);
      expect(invoice.patientName, 'Maria Clara');
      expect(invoice.lineItems.length, 2);
      expect(invoice.lineItems.first.itemName, 'Hepatitis B Pediatric Vaccine');
      expect(invoice.paymentMethod, 'GCash');
      expect(invoice.paidAt, isNotNull);
    });

    test('Invoice statutory amounts round deterministically to 2 decimal places', () {
      const invoice = Invoice(
        id: 'inv-round',
        patientId: 'p1',
        totalAmount: 100.0,
        discountType: 'senior',
        discountPercentage: 20.0,
      );
      // 100 / 1.12 = 89.2857... -> 89.29; 20% discount = 17.86; net = 71.43
      expect(invoice.vatableBase, 89.29);
      expect(invoice.vatExemptionAmount, 10.71);
      expect(invoice.discountAmount, 17.86);
      expect(invoice.netPayable, 71.43);
    });

    test('InventoryBatch & InventoryItem parse RPC column names (batch_id, item_id, item_name)', () {
      final expiringRpcRow = <String, dynamic>{
        'batch_id': 'b-rpc-1',
        'item_name': 'MMR Pediatric Vaccine',
        'batch_number': 'MMR-2026-09',
        'quantity_remaining': 6,
        'expiry_date': '2026-12-01',
        'days_remaining': 18,
      };
      final batch = InventoryBatch.fromJson(expiringRpcRow);
      expect(batch.id, 'b-rpc-1');
      expect(batch.itemName, 'MMR Pediatric Vaccine');
      expect(batch.quantityRemaining, 6);

      final lowStockRpcRow = <String, dynamic>{
        'item_id': 'i-rpc-2',
        'name': 'MMR Pediatric Vaccine',
        'category': 'Vaccines',
        'total_stock': 6,
        'reorder_level': 10,
      };
      final item = InventoryItem.fromJson(lowStockRpcRow);
      expect(item.id, 'i-rpc-2');
      expect(item.totalStock, 6);
      expect(item.isLowStock, isTrue);
    });

    test('InventoryRepository.calculateActiveStockFromBatches excludes expired batches', () {
      final today = InventoryBatch.manilaToday(DateTime.utc(2026, 11, 13, 2));
      final batches = [
        {'quantity_remaining': 50, 'expiry_date': '2026-11-12'}, // expired
        {'quantity_remaining': 12, 'expiry_date': '2026-11-13'}, // expires today (valid)
        {'quantity_remaining': 8, 'expiry_date': '2026-12-01'}, // future (valid)
      ];
      final stock = InventoryRepository.calculateActiveStockFromBatches(
        batches,
        today: today,
      );
      expect(stock, 20);
    });

    test('InvoiceRepository blocks mutations on paid invoices and records paymentMethod', () async {
      final repo = InvoiceRepository(client: null);
      final inv = await repo.createInvoice(patientId: 'p1', patientName: 'Juan Dela Cruz');
      await repo.addServiceItem(invoiceId: inv.id, serviceName: 'Consultation', fee: 500.0);

      final paidOk = await repo.markAsPaid(inv.id, paymentMethod: 'GCash');
      expect(paidOk, isTrue);

      final settled = await repo.getInvoiceById(inv.id);
      expect(settled?.isPaid, isTrue);
      expect(settled?.paymentMethod, 'GCash');
      expect(settled?.paidAt, isNotNull);

      final dispenseBlocked = await repo.dispenseItem(
        barcode: '4800016552011',
        invoiceId: inv.id,
        quantity: 1,
      );
      expect(dispenseBlocked.success, isFalse);
      expect(dispenseBlocked.message?.toLowerCase(), contains('paid'));

      final addAfterPaid = await repo.addServiceItem(
        invoiceId: inv.id,
        serviceName: 'Extra Fee',
        fee: 200.0,
      );
      expect(addAfterPaid, isNull);
    });

    test('AuthRepository always fails closed when Supabase is unconfigured (no in-memory fallback)', () async {
      final authRepo = AuthRepository(client: null);
      for (final email in [
        'nurse@primacare.ph',
        'doctor@primacare.ph',
        'admin@primacare.ph',
      ]) {
        await expectLater(
          () => authRepo.signInWithEmailPassword(
            email: email,
            password: 'any-password',
          ),
          throwsStateError,
        );
      }
      expect(authRepo.isAuthenticated, isFalse);
      expect(authRepo.activeProfile, isNull);
    });
  });

  group('Priority 3 QA Tests: Offline Persistence, Adapters & Safety Guards', () {
    test('OfflineSyncService persists queue to storage, restores it, and keeps failed actions', () async {
      final storage = _InMemoryQueueStorage();
      final service = OfflineSyncService.isolated(storage: storage);
      service.setConnectivity(false);

      await service.enqueueActionAndWait(
        type: SyncActionType.dispenseItem,
        payload: {'barcode': '4800016552011', 'invoiceId': 'inv-1', 'quantity': 1},
      );
      await service.enqueueActionAndWait(
        type: SyncActionType.markPaid,
        payload: {'invoiceId': 'inv-1', 'paymentMethod': 'Cash'},
      );
      expect(service.pendingCount, 2);

      // Simulate app restart by creating a new instance backed by same storage
      final restored = OfflineSyncService.isolated(storage: storage);
      await restored.restoreQueue();
      expect(restored.pendingCount, 2);
      expect(restored.queue.first.type, SyncActionType.dispenseItem);

      // Flush where first succeeds and second fails -> 1 remains persisted
      restored.setConnectivity(true);
      await restored.flushPendingQueue(
        handler: (action) async => action.type == SyncActionType.dispenseItem,
      );
      expect(restored.pendingCount, 1);
      expect(restored.queue.first.type, SyncActionType.markPaid);

      final reloadedAfterPartial = OfflineSyncService.isolated(storage: storage);
      await reloadedAfterPartial.restoreQueue();
      expect(reloadedAfterPartial.pendingCount, 1);
    });

    test('BiometricService and ThermalPrinterService honor configured hardware adapters', () async {
      final bio = BiometricService();
      bio.configureHardware(isSupported: true, isEnrolled: true);
      bio.setAdapter(_FailingBiometricAdapter());
      expect(await bio.authenticateWithBiometrics(), isFalse);

      final printer = ThermalPrinterService();
      printer.setAdapter(_DisconnectedPrinterAdapter());
      expect(await printer.printText('TEST SLIP'), isFalse);

      // Restore default adapters so shared singletons remain clean for other tests
      bio.setAdapter(null);
      printer.setAdapter(null);
    });

    test('ThermalPrinterService receipt includes payment method when paid', () {
      final printer = ThermalPrinterService();
      final receipt = printer.generateInvoiceReceiptText(
        invoice: const Invoice(
          id: 'inv-pay-1',
          patientId: 'p1',
          patientName: 'Juan Dela Cruz',
          status: 'paid',
          totalAmount: 500.0,
          paymentMethod: 'GCash',
        ),
        clinic: ClinicTenant.centralBranch(),
        cashierName: 'Nurse Sarah',
      );
      expect(receipt, contains('METHOD:'));
      expect(receipt, contains('GCash'));
    });

    testWidgets('VaccineScheduleScreen rejects zero-stock vaccine without billing phantom item', (tester) async {
      final zeroRepo = _ZeroStockVaccineInventoryRepo();
      final invoiceRepo = InvoiceRepository(client: null);
      final inv = await invoiceRepo.createInvoice(
        patientId: 'p-vac-test',
        patientName: 'Baby Mateo Cruz',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(zeroRepo),
            invoiceRepositoryProvider.overrideWithValue(invoiceRepo),
            patientListProvider.overrideWith(() => _MockPatientNotifier()),
          ],
          child: const MaterialApp(
            home: VaccineScheduleScreen(initialPatientId: 'p-vac-test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Dose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Record Dose'));
      await tester.pumpAndSettle();

      final updatedInv = await invoiceRepo.getInvoiceById(inv.id);
      expect(updatedInv?.lineItems, isEmpty);
      expect(updatedInv?.totalAmount, 0.0);
    });
  });
}

class _MockPatientNotifier extends PatientListNotifier {
  @override
  Future<List<Patient>> build() async => const [
        Patient(
          id: 'p-vac-test',
          fullName: 'Baby Mateo Cruz',
          dateOfBirth: '2026-01-10',
          contactNumber: '+63 917 555 0000',
        ),
      ];
}
