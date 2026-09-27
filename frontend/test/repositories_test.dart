import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/data/repositories/patient_repository.dart';
import 'package:primacare/data/repositories/invoice_repository.dart';

void main() {
  group('Repository Deterministic Unit Tests', () {
    test('PatientRepository returns fallback mock patients when client is null', () async {
      final repo = PatientRepository(client: null);
      final patients = await repo.getPatients();
      expect(patients.isNotEmpty, true);
      expect(patients.first.fullName, 'Juan Dela Cruz');
    });

    test('PatientRepository creates patient in fallback mode', () async {
      final repo = PatientRepository(client: null);
      final patient = await repo.createPatient(
        fullName: 'New Test Patient',
        contactNumber: '+639123456789',
      );
      expect(patient.fullName, 'New Test Patient');
      expect(patient.contactNumber, '+639123456789');
    });

    test('InvoiceRepository parses dispense RPC response', () {
      final rpcSuccessResponse = {
        'success': true,
        'item_name': 'Hepatitis B Pediatric Vaccine',
        'quantity_dispensed': 2,
        'amount_added': 900.0,
      };

      final result = DispenseResult.fromJson(rpcSuccessResponse);
      expect(result.success, true);
      expect(result.itemName, 'Hepatitis B Pediatric Vaccine');
      expect(result.quantityDispensed, 2);
      expect(result.amountAdded, 900.0);
    });

    test('InvoiceRepository handles failed dispense response', () {
      final rpcFailResponse = {
        'success': false,
        'message': 'Insufficient stock for this item',
      };

      final result = DispenseResult.fromJson(rpcFailResponse);
      expect(result.success, false);
      expect(result.message, 'Insufficient stock for this item');
    });
  });
}
