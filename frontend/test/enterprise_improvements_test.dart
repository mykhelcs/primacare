import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/domain/models/staff_profile.dart';
import 'package:primacare/domain/models/invoice.dart';
import 'package:primacare/data/services/offline_sync_service.dart';
import 'package:primacare/data/services/biometric_service.dart';
import 'package:primacare/data/services/thermal_printer_service.dart';

void main() {
  group('Enterprise Enhancements Deterministic Tests', () {
    test('Multi-Tenancy: ClinicTenant and StaffProfile tenancy isolation', () {
      final central = ClinicTenant.centralBranch();
      final north = ClinicTenant.northBranch();

      expect(central.code, 'PC-CENTRAL');
      expect(north.code, 'PC-NORTH');

      final staff = StaffProfile.mockNurse();
      expect(staff.clinic.code, 'PC-CENTRAL');

      final switched = staff.copyWith(clinic: north);
      expect(switched.clinic.code, 'PC-NORTH');
      expect(switched.clinicId, '00000000-0000-0000-0000-000000000002');
    });

    test('Offline Sync Service: enqueues actions and flushes when online', () async {
      final sync = OfflineSyncService();
      sync.clearQueue();

      // Go offline
      sync.setConnectivity(false);
      expect(sync.isOnline, false);

      // Enqueue offline dispense
      sync.enqueueAction(
        type: SyncActionType.dispenseItem,
        payload: {'barcode': '978020137962', 'invoiceId': 'inv-1', 'quantity': 2},
      );

      expect(sync.pendingCount, 1);
      expect(sync.queue.first.type, SyncActionType.dispenseItem);

      // Return online and flush
      sync.setConnectivity(true);
      expect(sync.isOnline, true);

      await sync.flushPendingQueue(
        handler: (action) async {
          expect(action.payload['barcode'], '978020137962');
          return true;
        },
      );

      expect(sync.pendingCount, 0);
    });

    test('Biometric Service: authenticates and supports device type configuration', () async {
      final bio = BiometricService();
      bio.configureHardware(
        isSupported: true,
        isEnrolled: true,
        type: BiometricType.faceId,
      );

      expect(bio.isBiometricSupported, true);
      expect(bio.biometricName, 'Face ID');

      final authSuccess = await bio.authenticateWithBiometrics();
      expect(authSuccess, true);
    });

    test('Thermal Printer Service: formats 58mm ESC/POS receipt and barcode stickers', () async {
      final printer = ThermalPrinterService();
      final clinic = ClinicTenant.centralBranch();

      final invoice = Invoice(
        id: 'inv-test-99',
        patientId: 'p1',
        patientName: 'Maria Santos',
        status: 'paid',
        totalAmount: 450.00,
        createdAt: DateTime(2026, 9, 28),
        lineItems: [
          const InvoiceLineItem(
            id: 'li-1',
            invoiceId: 'inv-test-99',
            inventoryBatchId: 'b1',
            itemName: 'Paracetamol 500mg',
            quantity: 3,
            unitCost: 150.00,
          ),
        ],
      );

      final receipt = printer.generateInvoiceReceiptText(
        invoice: invoice,
        clinic: clinic,
        cashierName: 'Nurse Sarah Jenkins',
      );

      expect(receipt.contains('PRIMACARE CENTRAL CLINIC'), true);
      expect(receipt.contains('OFFICIAL CLINICAL RECEIPT'), true);
      expect(receipt.contains('Paracetamol 50'), true);
      expect(receipt.contains('TOTAL DUE:'), true);
      expect(receipt.contains('₱450.00'), true);
      expect(receipt.contains('STATUS:'), true);
      expect(receipt.contains('PAID'), true);

      final label = printer.generateBatchBarcodeLabelText(
        itemName: 'Hepatitis B Pediatric',
        batchNumber: 'LOT-9921',
        barcode: 'BAR-HEP-B',
        expiryDate: DateTime(2027, 1, 1),
        clinic: clinic,
      );

      expect(label.contains('[PC-CENTRAL]'), true);
      expect(label.contains('LOT#: LOT-9921'), true);
      expect(label.contains('BARCODE: ||| BAR-HEP-B |||'), true);

      final printSuccess = await printer.printText(receipt);
      expect(printSuccess, true);
    });
  });
}
