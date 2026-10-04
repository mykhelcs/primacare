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

      // 2. Insert Core Clinical Items (Vaccines, Consumables, Pharmaceuticals, Clinical Services)
      final items = await client
          .from('inventory_items')
          .insert([
            // Vaccines
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
              'name': 'Pentavalent (DTP-HepB-Hib) Vaccine',
              'barcode': '4800016552013',
              'unit': 'vial',
              'unit_cost': 850.00,
              'category': 'Vaccines',
              'reorder_level': 15,
            },
            {
              'name': 'BCG Tuberculosis Vaccine',
              'barcode': '4800016552014',
              'unit': 'ampoule',
              'unit_cost': 380.00,
              'category': 'Vaccines',
              'reorder_level': 10,
            },
            {
              'name': 'Rotavirus Oral Vaccine',
              'barcode': '4800016552016',
              'unit': 'tube',
              'unit_cost': 1250.00,
              'category': 'Vaccines',
              'reorder_level': 8,
            },
            {
              'name': 'Inactivated Influenza Vaccine (Quadrivalent)',
              'barcode': '4800016552017',
              'unit': 'prefilled syringe',
              'unit_cost': 650.00,
              'category': 'Vaccines',
              'reorder_level': 20,
            },

            // Consumables
            {
              'name': 'Disposable Syringe 3ml with Needle',
              'barcode': '4800016552022',
              'unit': 'pcs',
              'unit_cost': 25.00,
              'category': 'Consumables',
              'reorder_level': 50,
            },
            {
              'name': 'Disposable Syringe 1ml Tuberculin',
              'barcode': '4800016552023',
              'unit': 'pcs',
              'unit_cost': 20.00,
              'category': 'Consumables',
              'reorder_level': 50,
            },
            {
              'name': 'Sterile Alcohol Swabs (70% Isopropyl)',
              'barcode': '4800016552025',
              'unit': 'box',
              'unit_cost': 110.00,
              'category': 'Consumables',
              'reorder_level': 10,
            },
            {
              'name': 'Sterile Gauze Sponges 2x2 (Pack of 100)',
              'barcode': '4800016552026',
              'unit': 'pack',
              'unit_cost': 140.00,
              'category': 'Consumables',
              'reorder_level': 10,
            },
            {
              'name': 'Examination Latex Gloves Medium',
              'barcode': '4800016552027',
              'unit': 'box',
              'unit_cost': 280.00,
              'category': 'Consumables',
              'reorder_level': 5,
            },

            // Pharmaceuticals
            {
              'name': 'Paracetamol 500mg Tablets',
              'barcode': '4800016552033',
              'unit': 'tabs',
              'unit_cost': 5.50,
              'category': 'Pharmaceuticals',
              'reorder_level': 100,
            },
            {
              'name': 'Paracetamol 120mg/5ml Pediatric Drops (60ml)',
              'barcode': '4800016552034',
              'unit': 'bottle',
              'unit_cost': 85.00,
              'category': 'Pharmaceuticals',
              'reorder_level': 20,
            },
            {
              'name': 'Amoxicillin 500mg Capsules',
              'barcode': '4800016552035',
              'unit': 'caps',
              'unit_cost': 8.00,
              'category': 'Pharmaceuticals',
              'reorder_level': 100,
            },
            {
              'name': 'Amoxicillin 250mg/5ml Suspension (60ml)',
              'barcode': '4800016552036',
              'unit': 'bottle',
              'unit_cost': 95.00,
              'category': 'Pharmaceuticals',
              'reorder_level': 15,
            },
            {
              'name': 'Oral Rehydration Salts (Hydrite Sachets)',
              'barcode': '4800016552037',
              'unit': 'sachet',
              'unit_cost': 15.00,
              'category': 'Pharmaceuticals',
              'reorder_level': 50,
            },
            {
              'name': 'Cetirizine 10mg Film-Coated Tablets',
              'barcode': '4800016552038',
              'unit': 'tabs',
              'unit_cost': 12.00,
              'category': 'Pharmaceuticals',
              'reorder_level': 50,
            },

            // Clinical Services
            {
              'name': 'General Medical Consultation',
              'barcode': 'SRV-001',
              'unit': 'service',
              'unit_cost': 500.00,
              'category': 'Services',
              'reorder_level': 0,
            },
            {
              'name': 'Pediatric Well-Baby & Immunization Exam',
              'barcode': 'SRV-002',
              'unit': 'service',
              'unit_cost': 600.00,
              'category': 'Services',
              'reorder_level': 0,
            },
            {
              'name': 'Nebulization Session (with Salbutamol)',
              'barcode': 'SRV-003',
              'unit': 'procedure',
              'unit_cost': 250.00,
              'category': 'Services',
              'reorder_level': 0,
            },
            {
              'name': 'Minor Wound Dressing & Antiseptic Care',
              'barcode': 'SRV-004',
              'unit': 'procedure',
              'unit_cost': 350.00,
              'category': 'Services',
              'reorder_level': 0,
            },
          ])
          .select();

      final insertedItems = items as List;
      final hepB = insertedItems.where((i) => i['barcode'] == '4800016552011').firstOrNull;
      final mmr = insertedItems.where((i) => i['barcode'] == '4800016552012').firstOrNull;
      final syringe = insertedItems.where((i) => i['barcode'] == '4800016552022').firstOrNull;
      final flu = insertedItems.where((i) => i['barcode'] == '4800016552017').firstOrNull;

      if (hepB != null && mmr != null && syringe != null && flu != null) {
        // 3. Insert Initial Batches with realistic dates (FIFO and Expiry)
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
          'item_id': mmr['id'],
          'batch_number': 'MMR-2026-09',
          'quantity_remaining': 6,
          'expiry_date': DateTime.now()
              .add(const Duration(days: 26))
              .toIso8601String()
              .substring(0, 10),
          'received_date': DateTime.now()
              .subtract(const Duration(days: 45))
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
        {
          'item_id': flu['id'],
          'batch_number': 'FLU-2026-22',
          'quantity_remaining': 35,
          'expiry_date': DateTime.now()
              .add(const Duration(days: 300))
              .toIso8601String()
              .substring(0, 10),
          'received_date': DateTime.now()
              .subtract(const Duration(days: 15))
              .toIso8601String()
              .substring(0, 10),
        },
      ]);
      }

      // 4. Insert Sample Patients with Full Clinical Data
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
      final juan = patients.where((p) => p['full_name'] == 'Juan Dela Cruz').firstOrNull;

      // 5. Insert an Open Invoice for Juan Dela Cruz
      if (juan != null) {
        await client.from('invoices').insert({
          'patient_id': juan['id'],
          'status': 'open',
          'total_amount': 0.00,
        });
      }

      debugPrint('Successfully seeded clinical data to Supabase!');
    } catch (e) {
      if (e.toString().contains('42501') || e.toString().contains('violates row-level security')) {
        debugPrint(
          'Supabase seeding notice: RLS policies prevented anon client seeding. Run supabase/migrations/20260929_fix_rls_and_patient_columns.sql to permit anon/authenticated seeding.',
        );
      } else {
        debugPrint('Supabase seeding notice: $e');
      }
    }
  }
}
