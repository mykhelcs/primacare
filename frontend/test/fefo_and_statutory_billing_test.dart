import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/domain/models/clinical_encounter.dart';
import 'package:primacare/domain/models/invoice.dart';
import 'package:primacare/data/repositories/invoice_repository.dart';
import 'package:primacare/data/repositories/inventory_repository.dart';

void main() {
  group('Medical Standards & Statutory Compliance Tests', () {
    test('ClinicalVitals: normal baseline, alerts, and serialization', () {
      final normal = ClinicalVitals.normalBaseline();
      expect(normal.bloodPressure, '120/80');
      expect(normal.temperature, 36.5);
      expect(normal.isFever, false);
      expect(normal.isHypertensive, false);

      final feverPatient = ClinicalVitals(
        bloodPressure: '110/70',
        heartRate: 98,
        temperature: 38.6,
        respiratoryRate: 20,
        recordedAt: DateTime.now(),
      );
      expect(feverPatient.isFever, true);
      expect(feverPatient.isHypertensive, false);

      final hypertensivePatient = ClinicalVitals(
        bloodPressure: '150/95',
        heartRate: 85,
        temperature: 36.8,
        respiratoryRate: 18,
        recordedAt: DateTime.now(),
      );
      expect(hypertensivePatient.isHypertensive, true);
      expect(hypertensivePatient.isFever, false);

      final json = normal.toJson();
      expect(json['blood_pressure'], '120/80');
      expect(json['temperature'], 36.5);

      final restored = ClinicalVitals.fromJson(json);
      expect(restored.bloodPressure, '120/80');
      expect(restored.temperature, 36.5);
    });

    test('Philippine Statutory Senior Citizen & PWD 20% Discount and VAT Exemption (RA 9994 / RA 10754)', () {
      // Example: Gross bill of ₱1,120.00
      // 12% VAT in Philippines means Vatable Base = 1120 / 1.12 = 1,000.00
      // VAT Exemption = 120.00
      // 20% Senior/PWD Discount = 1,000 * 0.20 = 200.00
      // Net Payable = 800.00
      const regularInvoice = Invoice(
        id: 'inv-test-1',
        patientId: 'pat-1',
        totalAmount: 1120.0,
        discountType: 'none',
      );

      expect(regularInvoice.grossAmount, 1120.0);
      expect(regularInvoice.hasSeniorOrPwdDiscount, false);
      expect(regularInvoice.discountAmount, 0.0);
      expect(regularInvoice.netPayable, 1120.0);
      expect(regularInvoice.regularVatAmount, closeTo(120.0, 0.01));

      const seniorInvoice = Invoice(
        id: 'inv-test-2',
        patientId: 'pat-2',
        totalAmount: 1120.0,
        discountType: 'senior',
        discountPercentage: 20.0,
        discountIdNumber: 'OSCA-12345',
      );

      expect(seniorInvoice.hasSeniorOrPwdDiscount, true);
      expect(seniorInvoice.vatableBase, closeTo(1000.0, 0.01));
      expect(seniorInvoice.vatExemptionAmount, closeTo(120.0, 0.01));
      expect(seniorInvoice.discountAmount, closeTo(200.0, 0.01));
      expect(seniorInvoice.netPayable, closeTo(800.0, 0.01));

      const pwdInvoice = Invoice(
        id: 'inv-test-3',
        patientId: 'pat-3',
        totalAmount: 1120.0,
        discountType: 'pwd',
        discountPercentage: 20.0,
        discountIdNumber: 'PWD-8899',
      );

      expect(pwdInvoice.hasSeniorOrPwdDiscount, true);
      expect(pwdInvoice.netPayable, closeTo(800.0, 0.01));
    });

    test('InvoiceRepository applyDiscount applies and recalculates invoice net payable', () async {
      final repo = InvoiceRepository();
      final inv = await repo.createInvoice(patientId: 'pat-discount-test', patientName: 'Maria Santos');

      await repo.addServiceItem(invoiceId: inv.id, serviceName: 'Medical Consultation', fee: 1120.0);

      final updatedSenior = await repo.applyDiscount(
        invoiceId: inv.id,
        discountType: 'senior',
        percentage: 20.0,
        discountIdNumber: 'OSCA-999',
      );

      expect(updatedSenior, isNotNull);
      expect(updatedSenior!.discountType, 'senior');
      expect(updatedSenior.discountIdNumber, 'OSCA-999');
      expect(updatedSenior.netPayable, closeTo(800.0, 0.01));

      final updatedRegular = await repo.applyDiscount(
        invoiceId: inv.id,
        discountType: 'none',
      );

      expect(updatedRegular, isNotNull);
      expect(updatedRegular!.discountType, 'none');
      expect(updatedRegular.netPayable, closeTo(1120.0, 0.01));
    });

    test('FEFO (First Expired, First Out) batch ordering prioritizes nearest expiry date', () async {
      final repo = InventoryRepository();
      final now = DateTime.now();

      // Create an item with two batches:
      // Batch A: received 60 days ago, expires in 90 days
      // Batch B: received 5 days ago, expires in 20 days (NEAR EXPIRY!)
      // FEFO MUST dispense Batch B first to prevent expiration waste!
      final item = await repo.createInventoryItem(
        name: 'FEFO Test Vaccine Vials',
        barcode: 'TEST-FEFO-BARCODE-99',
        unit: 'vial',
        unitCost: 300.0,
        category: 'Vaccines',
      );

      await repo.receiveStockBatch(
        itemId: item.id,
        batchNumber: 'BATCH-A-LATER-EXP',
        quantity: 10,
        expiryDate: now.add(const Duration(days: 90)),
      );

      await repo.receiveStockBatch(
        itemId: item.id,
        batchNumber: 'BATCH-B-EARLIER-EXP',
        quantity: 5,
        expiryDate: now.add(const Duration(days: 20)),
      );

      final batches = await repo.getBatchesForItem(item.id);
      expect(batches.length, 2);
      // Batch B must be first because it expires first!
      expect(batches.first.batchNumber, 'BATCH-B-EARLIER-EXP');
      expect(batches.last.batchNumber, 'BATCH-A-LATER-EXP');

      // Dispense 3 units using FEFO
      await repo.dispenseItemFEFO(itemId: item.id, quantity: 3);

      final updatedBatches = await repo.getBatchesForItem(item.id);
      final batchB = updatedBatches.firstWhere((b) => b.batchNumber == 'BATCH-B-EARLIER-EXP');
      expect(batchB.quantityRemaining, 2); // 5 - 3 = 2
    });
  });
}
