import 'package:flutter/foundation.dart';
import '../../data/services/supabase_service.dart';

class SupabaseSeeder {
  static Future<bool> isDatabaseReady() async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client
          .from('inventory_items')
          .select('id')
          .limit(1);
      return true;
    } catch (e) {
      debugPrint('Supabase tables check: $e');
      return false;
    }
  }

  static Future<void> seedInitialClinicalData() async {
    if (!SupabaseService.isInitialized) return;
    final client = SupabaseService.client;

    try {
      // 1. Check if items already exist
      final existingItems = await client.from('inventory_items').select('id');
      if ((existingItems as List).isNotEmpty) {
        debugPrint('Clinical inventory items already seeded.');
        return;
      }

      // 2. Insert Core Clinical Items
      final items = await client
          .from('inventory_items')
          .insert([
            {
              'name': 'Hepatitis B Pediatric Vaccine',
              'barcode': '4800016552011',
              'unit': 'vial',
              'unit_cost': 450.00,
              'category': 'Vaccines',
              'reorder_level': 10,
            },
            {
              'name': 'MMR Pediatric Vaccine',
              'barcode': '4800016552012',
              'unit': 'vial',
              'unit_cost': 720.00,
              'category': 'Vaccines',
              'reorder_level': 10,
            },
            {
              'name': 'Disposable Syringe 3ml',
              'barcode': '4800016552022',
              'unit': 'pcs',
              'unit_cost': 25.00,
              'category': 'Consumables',
              'reorder_level': 50,
            },
            {
              'name': 'Paracetamol 500mg Tablets',
              'barcode': '4800016552033',
              'unit': 'tabs',
              'unit_cost': 5.50,
              'category': 'Pharmaceuticals',
              'reorder_level': 100,
            },
          ])
          .select();

      final insertedItems = items as List;
      final hepB = insertedItems.firstWhere((i) => i['barcode'] == '4800016552011');
      final syringe = insertedItems.firstWhere((i) => i['barcode'] == '4800016552022');

      // 3. Insert Initial Batches
      await client.from('inventory_batches').insert([
        {
          'item_id': hepB['id'],
          'batch_number': 'HB-2026-04',
          'quantity_remaining': 12,
          'expiry_date': DateTime.now()
              .add(const Duration(days: 18))
              .toIso8601String()
              .substring(0, 10),
          'received_date': DateTime.now()
              .subtract(const Duration(days: 60))
              .toIso8601String()
              .substring(0, 10),
        },
        {
          'item_id': syringe['id'],
          'batch_number': 'SY-2026-11',
          'quantity_remaining': 120,
          'expiry_date': DateTime.now()
              .add(const Duration(days: 300))
              .toIso8601String()
              .substring(0, 10),
          'received_date': DateTime.now()
              .subtract(const Duration(days: 30))
              .toIso8601String()
              .substring(0, 10),
        },
      ]);

      // 4. Insert Sample Patients
      final patientResult = await client
          .from('patients')
          .insert([
            {
              'full_name': 'Juan Dela Cruz',
              'date_of_birth': '1990-05-15',
              'contact_number': '+63 917 123 4567',
              'email': 'juan@example.ph',
            },
            {
              'full_name': 'Maria Santos',
              'date_of_birth': '1985-11-02',
              'contact_number': '+63 928 987 6543',
              'email': 'maria@example.ph',
            },
            {
              'full_name': 'Roberto Lim',
              'date_of_birth': '1974-08-23',
              'contact_number': '+63 905 456 7890',
              'email': 'roberto@example.ph',
            },
            {
              'full_name': 'Elena Garcia',
              'date_of_birth': '1998-01-11',
              'contact_number': '+63 919 234 5678',
              'email': 'elena@example.ph',
            },
          ])
          .select();

      final patients = patientResult as List;
      final juan = patients.firstWhere((p) => p['full_name'] == 'Juan Dela Cruz');

      // 5. Insert an Open Invoice for Juan Dela Cruz
      await client.from('invoices').insert({
        'patient_id': juan['id'],
        'status': 'open',
        'total_amount': 0.00,
      });

      debugPrint('Successfully seeded clinical data to Supabase!');
    } catch (e) {
      debugPrint('Error seeding Supabase: $e');
    }
  }
}
