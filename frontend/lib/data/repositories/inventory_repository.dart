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

  Future<List<InventoryBatch>> getExpiringBatches({int daysAhead = 30}) async {
    if (_client == null) {
      return _mockBatches.where((b) => b.isCriticalExpiry).toList();
    }

    try {
      final response = await _client.rpc('get_expiring_batches', params: {
        'days_ahead': daysAhead,
      });
      return (response as List)
          .map((b) => InventoryBatch.fromJson(b as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockBatches.where((b) => b.isCriticalExpiry).toList();
    }
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    if (_client == null) {
      return _mockItems.where((i) => i.isLowStock).toList();
    }

    try {
      final response = await _client.rpc('get_low_stock_items');
      return (response as List)
          .map((i) => InventoryItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockItems.where((i) => i.isLowStock).toList();
    }
  }

  Future<String> receiveStockBatch({
    required String itemId,
    required String batchNumber,
    required int quantity,
    required DateTime expiryDate,
  }) async {
    if (_client == null) {
      final newBatchId = 'b_${DateTime.now().millisecondsSinceEpoch}';
      _mockBatches.insert(
        0,
        InventoryBatch(
          id: newBatchId,
          itemId: itemId,
          batchNumber: batchNumber,
          quantityRemaining: quantity,
          expiryDate: expiryDate,
          receivedDate: DateTime.now(),
        ),
      );
      return newBatchId;
    }

    try {
      final response = await _client.rpc('receive_stock_batch', params: {
        'p_item_id': itemId,
        'p_batch_number': batchNumber,
        'p_quantity': quantity,
        'p_expiry_date': expiryDate.toIso8601String().substring(0, 10),
      });
      return response.toString();
    } catch (_) {
      final newBatchId = 'b_${DateTime.now().millisecondsSinceEpoch}';
      return newBatchId;
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

  static final List<InventoryBatch> _mockBatches = [
    InventoryBatch(
      id: 'b1',
      itemId: 'i1',
      batchNumber: 'HB-2026-04',
      quantityRemaining: 12,
      expiryDate: DateTime.now().add(const Duration(days: 18)),
      receivedDate: DateTime.now().subtract(const Duration(days: 60)),
    ),
    InventoryBatch(
      id: 'b2',
      itemId: 'i2',
      batchNumber: 'MMR-2026-09',
      quantityRemaining: 6,
      expiryDate: DateTime.now().add(const Duration(days: 26)),
      receivedDate: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];
}
