import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/domain/models/inventory_item.dart';
import 'package:primacare/domain/models/notification_item.dart';
import 'package:primacare/domain/models/report_item.dart';
import 'package:primacare/domain/models/user_role.dart';
import 'package:primacare/data/repositories/inventory_repository.dart';
import 'package:primacare/data/repositories/notification_repository.dart';
import 'package:primacare/data/repositories/report_repository.dart';
import 'package:primacare/data/services/security_service.dart';

void main() {
  group('Phases 2-5 Domain & Logic Tests', () {
    test('Phase 2: InventoryBatch critical expiry check', () {
      final now = DateTime.now();
      final batchCritical = InventoryBatch(
        id: 'b1',
        itemId: 'i1',
        batchNumber: 'LOT-100',
        quantityRemaining: 15,
        expiryDate: now.add(const Duration(days: 15)),
        receivedDate: now.subtract(const Duration(days: 30)),
      );

      expect(batchCritical.isCriticalExpiry, true);
      expect(batchCritical.isExpired, false);
    });

    test('Phase 2: InventoryRepository returns expiring batches and receives stock', () async {
      final repo = InventoryRepository(client: null);
      final expiring = await repo.getExpiringBatches();
      expect(expiring.isNotEmpty, true);

      final batchId = await repo.receiveStockBatch(
        itemId: 'i1',
        batchNumber: 'NEW-LOT-01',
        quantity: 50,
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );
      expect(batchId.isNotEmpty, true);
    });

    test('Phase 3: NotificationItem parsing and status checks', () {
      final json = {
        'id': 'notif-1',
        'patient_id': 'p-1',
        'type': 'vaccine_reminder',
        'message': 'Reminder for Hepatitis B Dose 2',
        'status': 'pending',
        'scheduled_for': DateTime.now().toIso8601String(),
      };

      final notif = NotificationItem.fromJson(json);
      expect(notif.id, 'notif-1');
      expect(notif.isPending, true);
      expect(notif.isSent, false);
    });

    test('Phase 3: NotificationRepository queues and marks sent', () async {
      final repo = NotificationRepository(client: null);
      final queue = await repo.getNotificationQueue();
      expect(queue.isNotEmpty, true);

      final scheduledId = await repo.scheduleVaccineReminder(
        patientId: 'p1',
        vaccineName: 'Polio Booster',
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );
      expect(scheduledId.isNotEmpty, true);

      final sentSuccess = await repo.sendManualNotification('n1');
      expect(sentSuccess, true);
    });

    test('Phase 4: BillingSummaryReport calculations and CSV export', () async {
      final summary = BillingSummaryReport(
        monthKey: '2026-09',
        totalInvoices: 50,
        paidInvoices: 44,
        openInvoices: 6,
        totalBilledAmount: 148200.0,
        totalCollectedAmount: 130000.0,
      );

      expect(summary.collectionRate, closeTo(87.7, 0.2));

      final repo = ReportRepository(client: null);
      final summaries = await repo.getMonthlyBillingSummary();
      final leakages = await repo.getLeakageRecoveryReport();
      final csv = repo.exportReportsAsCsv(
        billingSummaries: summaries,
        leakageReports: leakages,
      );
      expect(csv.contains('PRIMACARE FINANCIAL'), true);
      expect(csv.contains('Hepatitis B Pediatric Vaccine'), true);
    });

    test('Phase 5: UserRole permission checks and SecurityService', () {
      expect(UserRole.admin.canViewFinancialReports, true);
      expect(UserRole.nurse.canViewFinancialReports, false);
      expect(UserRole.nurse.canDispense, true);

      final sec = SecurityService();
      sec.setCurrentRole(UserRole.admin);
      expect(sec.currentRole, UserRole.admin);
      sec.recordUserInteraction();
    });
  });
}
