import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/inventory_item.dart';
import '../services/supabase_service.dart';

class InventoryRepository {
  final SupabaseClient? _client;

  InventoryRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  static final List<InventoryItem> _localCreatedItems = [];

  /// Sums remaining stock across non-expired batches using Asia/Manila calendar date.
  static int calculateActiveStockFromBatches(
    List<dynamic> batches, {
    DateTime? today,
  }) {
    final manilaDate = today ?? InventoryBatch.manilaToday();
    int total = 0;
    for (final raw in batches) {
      if (raw is! Map) continue;
      final qty = (raw['quantity_remaining'] as num?)?.toInt() ?? 0;
      if (qty <= 0) continue;
      final expStr = raw['expiry_date'] as String?;
      if (expStr != null && expStr.isNotEmpty) {
        final parsed = DateTime.tryParse(expStr);
        if (parsed != null) {
          final expCal = DateTime(parsed.year, parsed.month, parsed.day);
          if (expCal.isBefore(manilaDate)) {
            continue;
          }
        }
      }
      total += qty;
    }
    return total;
  }

  Future<List<InventoryItem>> getInventoryItems() async {
    if (_client == null) {
      return [..._localCreatedItems, ..._mockItems];
    }

    try {
      final response = await _client
          .from('inventory_items')
          .select('*, inventory_batches(quantity_remaining, expiry_date)');
      final remoteList = (response as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final batches = map['inventory_batches'];
        map['total_stock'] =
            batches is List ? calculateActiveStockFromBatches(batches) : 0;
        return InventoryItem.fromJson(map);
      }).toList();

      final remoteIds = remoteList.map((i) => i.id).toSet();
      final remoteBarcodes = remoteList.map((i) => i.barcode).toSet();

      final unmerged = _localCreatedItems.where(
        (i) => !remoteIds.contains(i.id) && !remoteBarcodes.contains(i.barcode),
      );
      return [...unmerged, ...remoteList];
    } catch (_) {
      return [..._localCreatedItems];
    }
  }

  Future<InventoryItem?> getItemByBarcode(String barcode) async {
    final localMatch = _localCreatedItems.where((i) => i.barcode == barcode);
    if (localMatch.isNotEmpty) return localMatch.first;

    if (_client == null) {
      final found = _mockItems.where((i) => i.barcode == barcode);
      return found.isNotEmpty ? found.first : null;
    }

    try {
      final response = await _client
          .from('inventory_items')
          .select('*, inventory_batches(quantity_remaining, expiry_date)')
          .eq('barcode', barcode)
          .maybeSingle();
      if (response != null) {
        final map = Map<String, dynamic>.from(response);
        final batches = map['inventory_batches'];
        map['total_stock'] =
            batches is List ? calculateActiveStockFromBatches(batches) : 0;
        return InventoryItem.fromJson(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<InventoryBatch>> getExpiringBatches({int daysAhead = 30}) async {
    if (_client == null) {
      return _mockBatches
          .where((b) => !b.isExpired && b.daysUntilExpiry <= daysAhead)
          .toList();
    }

    try {
      final response = await _client.rpc('get_expiring_batches', params: {
        'days_ahead': daysAhead,
      });
      return (response as List)
          .map((b) => InventoryBatch.fromJson(b as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Live fallback query on table directly if RPC is unavailable
      try {
        final today = InventoryBatch.manilaToday();
        final todayStr = today.toIso8601String().substring(0, 10);
        final maxExpiry =
            today.add(Duration(days: daysAhead)).toIso8601String().substring(0, 10);
        final response = await _client
            .from('inventory_batches')
            .select()
            .gt('quantity_remaining', 0)
            .gte('expiry_date', todayStr)
            .lte('expiry_date', maxExpiry)
            .order('expiry_date', ascending: true);
        return (response as List)
            .map((b) => InventoryBatch.fromJson(b as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
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
      final all = await getInventoryItems();
      return all.where((i) => i.isLowStock).toList();
    }
  }

  Future<InventoryItem> createInventoryItem({
    required String name,
    required String barcode,
    required String unit,
    required double unitCost,
    required String category,
    int reorderLevel = 10,
  }) async {
    if (_client != null) {
      final response = await _client
          .from('inventory_items')
          .insert({
            'name': name,
            'barcode': barcode,
            'unit': unit,
            'unit_cost': unitCost,
            'category': category,
            'reorder_level': reorderLevel,
          })
          .select()
          .single();
      final created = InventoryItem.fromJson(response);
      _localCreatedItems.insert(0, created);
      return created;
    }

    final fallback = InventoryItem(
      id: 'i_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      barcode: barcode,
      unit: unit,
      unitCost: unitCost,
      category: category,
      reorderLevel: reorderLevel,
      totalStock: 0,
    );
    _localCreatedItems.insert(0, fallback);
    return fallback;
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
      final itemIdx = _mockItems.indexWhere((i) => i.id == itemId);
      if (itemIdx != -1) {
        final old = _mockItems[itemIdx];
        _mockItems[itemIdx] = InventoryItem(
          id: old.id,
          name: old.name,
          barcode: old.barcode,
          unit: old.unit,
          unitCost: old.unitCost,
          category: old.category,
          reorderLevel: old.reorderLevel,
          totalStock: old.totalStock + quantity,
        );
      }
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
      // Direct table insert if RPC is missing
      try {
        final insertRes = await _client
            .from('inventory_batches')
            .insert({
              'item_id': itemId,
              'batch_number': batchNumber,
              'quantity_remaining': quantity,
              'expiry_date': expiryDate.toIso8601String().substring(0, 10),
              'received_date': DateTime.now().toIso8601String().substring(0, 10),
            })
            .select('id')
            .single();
        return insertRes['id'] as String;
      } catch (err) {
        rethrow;
      }
    }
  }

  Future<List<InventoryBatch>> getBatchesForItem(String itemId) async {
    final today = InventoryBatch.manilaToday();

    if (_client != null) {
      try {
        final todayStr = today.toIso8601String().substring(0, 10);
        final response = await _client
            .from('inventory_batches')
            .select()
            .eq('item_id', itemId)
            .gt('quantity_remaining', 0)
            .gte('expiry_date', todayStr)
            .order('expiry_date', ascending: true)
            .order('received_date', ascending: true);
        return (response as List)
            .map((b) => InventoryBatch.fromJson(b as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }

    final batches = _mockBatches
        .where((b) =>
            b.itemId == itemId &&
            b.quantityRemaining > 0 &&
            !b.expiryDate.isBefore(today))
        .toList();

    // FEFO: Sort by expiry_date ASC, then received_date ASC
    batches.sort((a, b) {
      final cmp = a.expiryDate.compareTo(b.expiryDate);
      if (cmp != 0) return cmp;
      return a.receivedDate.compareTo(b.receivedDate);
    });
    return batches;
  }

  Future<bool> dispenseItemFEFO({
    required String itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) return false;
    final batches = await getBatchesForItem(itemId);
    final totalAvailable = batches.fold<int>(0, (sum, b) => sum + b.quantityRemaining);
    if (totalAvailable < quantity) {
      return false;
    }

    int needed = quantity;
    for (final b in batches) {
      if (needed <= 0) break;
      final deduct = b.quantityRemaining >= needed ? needed : b.quantityRemaining;

      if (_client != null) {
        await _client
            .from('inventory_batches')
            .update({'quantity_remaining': b.quantityRemaining - deduct})
            .eq('id', b.id);
      } else {
        final idx = _mockBatches.indexWhere((x) => x.id == b.id);
        if (idx != -1) {
          _mockBatches[idx] = b.copyWith(
            quantityRemaining: b.quantityRemaining - deduct,
          );
        }
      }
      needed -= deduct;
    }

    final itemIdx = _mockItems.indexWhere((i) => i.id == itemId);
    if (itemIdx != -1) {
      final old = _mockItems[itemIdx];
      final newStock = (old.totalStock - quantity) >= 0 ? (old.totalStock - quantity) : 0;
      _mockItems[itemIdx] = old.copyWith(totalStock: newStock);
    }
    return needed == 0;
  }

  static final List<InventoryItem> _mockItems = [
    // Vaccines
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
      id: 'i5',
      name: 'Pentavalent (DTP-HepB-Hib) Vaccine',
      barcode: '4800016552013',
      unit: 'vial',
      unitCost: 850.0,
      category: 'Vaccines',
      reorderLevel: 15,
      totalStock: 18,
    ),
    const InventoryItem(
      id: 'i6',
      name: 'BCG Tuberculosis Vaccine',
      barcode: '4800016552014',
      unit: 'ampoule',
      unitCost: 380.0,
      category: 'Vaccines',
      reorderLevel: 10,
      totalStock: 14,
    ),
    const InventoryItem(
      id: 'i7',
      name: 'Rotavirus Oral Vaccine',
      barcode: '4800016552016',
      unit: 'tube',
      unitCost: 1250.0,
      category: 'Vaccines',
      reorderLevel: 8,
      totalStock: 9,
    ),
    const InventoryItem(
      id: 'i8',
      name: 'Inactivated Influenza Vaccine (Quadrivalent)',
      barcode: '4800016552017',
      unit: 'prefilled syringe',
      unitCost: 650.0,
      category: 'Vaccines',
      reorderLevel: 20,
      totalStock: 35,
    ),

    // Consumables
    const InventoryItem(
      id: 'i3',
      name: 'Disposable Syringe 3ml with Needle',
      barcode: '4800016552022',
      unit: 'pcs',
      unitCost: 25.0,
      category: 'Consumables',
      reorderLevel: 50,
      totalStock: 120,
    ),
    const InventoryItem(
      id: 'i9',
      name: 'Disposable Syringe 1ml Tuberculin',
      barcode: '4800016552023',
      unit: 'pcs',
      unitCost: 20.0,
      category: 'Consumables',
      reorderLevel: 50,
      totalStock: 95,
    ),
    const InventoryItem(
      id: 'i10',
      name: 'Sterile Alcohol Swabs (70% Isopropyl)',
      barcode: '4800016552025',
      unit: 'box',
      unitCost: 110.0,
      category: 'Consumables',
      reorderLevel: 10,
      totalStock: 15,
    ),
    const InventoryItem(
      id: 'i11',
      name: 'Sterile Gauze Sponges 2x2 (Pack of 100)',
      barcode: '4800016552026',
      unit: 'pack',
      unitCost: 140.0,
      category: 'Consumables',
      reorderLevel: 10,
      totalStock: 8,
    ),
    const InventoryItem(
      id: 'i12',
      name: 'Examination Latex Gloves Medium',
      barcode: '4800016552027',
      unit: 'box',
      unitCost: 280.0,
      category: 'Consumables',
      reorderLevel: 5,
      totalStock: 12,
    ),

    // Pharmaceuticals
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
    const InventoryItem(
      id: 'i13',
      name: 'Paracetamol 120mg/5ml Pediatric Drops (60ml)',
      barcode: '4800016552034',
      unit: 'bottle',
      unitCost: 85.0,
      category: 'Pharmaceuticals',
      reorderLevel: 20,
      totalStock: 30,
    ),
    const InventoryItem(
      id: 'i14',
      name: 'Amoxicillin 500mg Capsules',
      barcode: '4800016552035',
      unit: 'caps',
      unitCost: 8.0,
      category: 'Pharmaceuticals',
      reorderLevel: 100,
      totalStock: 180,
    ),
    const InventoryItem(
      id: 'i15',
      name: 'Amoxicillin 250mg/5ml Suspension (60ml)',
      barcode: '4800016552036',
      unit: 'bottle',
      unitCost: 95.0,
      category: 'Pharmaceuticals',
      reorderLevel: 15,
      totalStock: 22,
    ),
    const InventoryItem(
      id: 'i16',
      name: 'Oral Rehydration Salts (Hydrite Sachets)',
      barcode: '4800016552037',
      unit: 'sachet',
      unitCost: 15.0,
      category: 'Pharmaceuticals',
      reorderLevel: 50,
      totalStock: 80,
    ),
    const InventoryItem(
      id: 'i17',
      name: 'Cetirizine 10mg Film-Coated Tablets',
      barcode: '4800016552038',
      unit: 'tabs',
      unitCost: 12.0,
      category: 'Pharmaceuticals',
      reorderLevel: 50,
      totalStock: 65,
    ),

    // Clinical Services
    const InventoryItem(
      id: 's1',
      name: 'General Medical Consultation',
      barcode: 'SRV-001',
      unit: 'service',
      unitCost: 500.0,
      category: 'Services',
      reorderLevel: 0,
      totalStock: 999,
    ),
    const InventoryItem(
      id: 's2',
      name: 'Pediatric Well-Baby & Immunization Exam',
      barcode: 'SRV-002',
      unit: 'service',
      unitCost: 600.0,
      category: 'Services',
      reorderLevel: 0,
      totalStock: 999,
    ),
    const InventoryItem(
      id: 's3',
      name: 'Nebulization Session (with Salbutamol)',
      barcode: 'SRV-003',
      unit: 'procedure',
      unitCost: 250.0,
      category: 'Services',
      reorderLevel: 0,
      totalStock: 999,
    ),
    const InventoryItem(
      id: 's4',
      name: 'Minor Wound Dressing & Antiseptic Care',
      barcode: 'SRV-004',
      unit: 'procedure',
      unitCost: 350.0,
      category: 'Services',
      reorderLevel: 0,
      totalStock: 999,
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
    InventoryBatch(
      id: 'b3',
      itemId: 'i5',
      batchNumber: 'PV-2026-11',
      quantityRemaining: 18,
      expiryDate: DateTime.now().add(const Duration(days: 180)),
      receivedDate: DateTime.now().subtract(const Duration(days: 20)),
    ),
    InventoryBatch(
      id: 'b4',
      itemId: 'i8',
      batchNumber: 'FLU-2026-22',
      quantityRemaining: 35,
      expiryDate: DateTime.now().add(const Duration(days: 300)),
      receivedDate: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];
}
