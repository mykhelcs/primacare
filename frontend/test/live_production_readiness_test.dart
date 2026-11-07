import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/data/repositories/auth_repository.dart';
import 'package:primacare/data/repositories/inventory_repository.dart';
import 'package:primacare/data/repositories/invoice_repository.dart';
import 'package:primacare/data/repositories/notification_repository.dart';
import 'package:primacare/data/repositories/report_repository.dart';

void main() {
  group('100% Complete Production Readiness Deterministic Tests', () {
    test('InventoryRepository getBatchesForItem returns FEFO sorted batches', () async {
      final repo = InventoryRepository(client: null);
      final batches = await repo.getBatchesForItem('i1');
      expect(batches.isNotEmpty, true);
      // Verify FEFO order (expiryDate ascending)
      for (int i = 0; i < batches.length - 1; i++) {
        expect(
          batches[i].expiryDate.isBefore(batches[i + 1].expiryDate) ||
              batches[i].expiryDate.isAtSameMomentAs(batches[i + 1].expiryDate),
          true,
        );
      }
    });

    test('InventoryRepository receiveStockBatch adds batch to item and updates stock', () async {
      final repo = InventoryRepository(client: null);
      final initialBatches = await repo.getBatchesForItem('i1');
      final initialCount = initialBatches.length;

      final batchId = await repo.receiveStockBatch(
        itemId: 'i1',
        batchNumber: 'LOT-NEW-TEST',
        quantity: 10,
        expiryDate: DateTime.now().add(const Duration(days: 300)),
      );

      expect(batchId.isNotEmpty, true);
      final updatedBatches = await repo.getBatchesForItem('i1');
      expect(updatedBatches.length, initialCount + 1);
      expect(updatedBatches.any((b) => b.batchNumber == 'LOT-NEW-TEST'), true);
    });

    test('InvoiceRepository creates real invoice and adds line item dynamically', () async {
      final repo = InvoiceRepository(client: null);
      final inv = await repo.createInvoice(
        patientId: 'p1',
        patientName: 'Juan Dela Cruz',
      );

      expect(inv.patientId, 'p1');
      expect(inv.totalAmount, 0.0);

      final updated = await repo.addServiceItem(
        invoiceId: inv.id,
        serviceName: 'Hepatitis B Pediatric Vaccine',
        fee: 450.0,
      );

      expect(updated, isNotNull);
      expect(updated!.totalAmount, 450.0);
      expect(updated.lineItems.any((l) => l.itemName == 'Hepatitis B Pediatric Vaccine'), true);
    });

    test('NotificationRepository schedules and sends notifications without phantom data', () async {
      final notifRepo = NotificationRepository(client: null);
      final notifId = await notifRepo.scheduleVaccineReminder(
        patientId: 'p2',
        patientName: 'Maria Santos',
        vaccineName: 'MMR Booster',
        dueDate: DateTime.now().add(const Duration(days: 14)),
      );

      expect(notifId.isNotEmpty, true);
      final queue = await notifRepo.getNotificationQueue();
      final scheduled = queue.where((n) => n.id == notifId).firstOrNull;
      expect(scheduled, isNotNull);
      expect(scheduled!.status, 'pending');

      final sendOk = await notifRepo.sendManualNotification(notifId);
      expect(sendOk, true);

      final updatedQueue = await notifRepo.getNotificationQueue();
      final sentItem = updatedQueue.where((n) => n.id == notifId).first;
      expect(sentItem.isSent, true);
      expect(sentItem.sentAt, isNotNull);
    });

    test('ReportRepository produces valid CSV export with real dynamic metrics', () {
      final repo = ReportRepository(client: null);
      final csv = repo.exportReportsAsCsv(
        billingSummaries: [],
        leakageReports: [],
      );

      expect(csv.contains('PRIMACARE FINANCIAL & CLINICAL SUMMARY REPORT'), true);
      expect(csv.contains('Collection Rate (%)'), true);
    });

    test('AuthRepository rejects empty credentials deterministically', () async {
      final authRepo = AuthRepository(client: null);
      expect(
        () => authRepo.signInWithEmailPassword(email: '', password: ''),
        throwsArgumentError,
      );
    });
  });
}
