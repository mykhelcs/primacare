import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/inventory_item.dart';
import '../services/supabase_service.dart';

class InventoryRepository {
  final SupabaseClient? _client;

  InventoryRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  Future<List<InventoryItem>> getInventoryItems() async {
    if (_client == null) {
      return _mockItems;
    }

    try {
      final response = await _client.from('inventory_items').select();
      return (response as List)
          .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockItems;
    }
  }

  Future<InventoryItem?> getItemByBarcode(String barcode) async {
    if (_client == null) {
      final found = _mockItems.where((i) => i.barcode == barcode);
      return found.isNotEmpty ? found.first : null;
    }

    try {
      final response = await _client
          .from('inventory_items')
          .select()
          .eq('barcode', barcode)
          .maybeSingle();
      if (response == null) return null;
      return InventoryItem.fromJson(response);
    } catch (_) {
      final found = _mockItems.where((i) => i.barcode == barcode);
      return found.isNotEmpty ? found.first : null;
    }
  }

  static final List<InventoryItem> _mockItems = [
    const InventoryItem(
      id: 'i1',
      name: 'Hepatitis B Pediatric Vaccine',
      barcode: '4800016552011',
      unit: 'vial',
      unitCost: 450.0,
      category: 'Vaccines',
      reorderLevel: 10,
      totalStock: 24,
    ),
    const InventoryItem(
      id: 'i2',
      name: 'MMR Pediatric Vaccine',
      barcode: '4800016552012',
      unit: 'vial',
      unitCost: 720.0,
      category: 'Vaccines',
      reorderLevel: 10,
      totalStock: 6,
    ),
    const InventoryItem(
      id: 'i3',
      name: 'Disposable Syringe 3ml',
      barcode: '4800016552022',
      unit: 'pcs',
      unitCost: 25.0,
      category: 'Consumables',
      reorderLevel: 50,
      totalStock: 120,
    ),
    const InventoryItem(
      id: 'i4',
      name: 'Paracetamol 500mg Tablets',
      barcode: '4800016552033',
      unit: 'tabs',
      unitCost: 5.50,
      category: 'Pharmaceuticals',
      reorderLevel: 100,
      totalStock: 250,
    ),
  ];
}
