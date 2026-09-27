import 'package:flutter_test/flutter_test.dart';
import 'package:primacare/domain/models/patient.dart';
import 'package:primacare/domain/models/inventory_item.dart';
import 'package:primacare/domain/models/invoice.dart';

void main() {
  group('Domain Models Deterministic Tests', () {
    test('Patient model converts to and from json', () {
      final json = {
        'id': 'p1',
        'full_name': 'Juan Dela Cruz',
        'date_of_birth': '1990-05-15',
        'contact_number': '+639171234567',
        'email': 'juan@example.ph',
      };

      final patient = Patient.fromJson(json);
      expect(patient.id, 'p1');
      expect(patient.fullName, 'Juan Dela Cruz');
      expect(patient.contactNumber, '+639171234567');
      expect(patient.toJson()['full_name'], 'Juan Dela Cruz');
    });

    test('InventoryItem model computes stock and expiry state', () {
      final json = {
        'id': 'item-1',
        'name': 'Hepatitis B Vaccine',
        'barcode': '4800016552011',
        'unit': 'vial',
        'unit_cost': 450.0,
        'category': 'vaccine',
        'reorder_level': 10,
        'total_stock': 24,
      };

      final item = InventoryItem.fromJson(json);
      expect(item.id, 'item-1');
      expect(item.name, 'Hepatitis B Vaccine');
      expect(item.isLowStock, false);
    });

    test('InvoiceLineItem computes line total accurately', () {
      final lineItem = InvoiceLineItem(
        id: 'li-1',
        invoiceId: 'inv-1',
        itemName: 'Paracetamol 500mg',
        quantity: 10,
        unitCost: 5.50,
      );

      expect(lineItem.lineTotal, 55.0);
    });
  });
}
