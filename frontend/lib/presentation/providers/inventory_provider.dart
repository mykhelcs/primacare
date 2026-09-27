import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../domain/models/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository();
});

final inventoryListProvider =
    AsyncNotifierProvider<InventoryListNotifier, List<InventoryItem>>(
  InventoryListNotifier.new,
);

class InventoryListNotifier extends AsyncNotifier<List<InventoryItem>> {
  @override
  Future<List<InventoryItem>> build() async {
    final repo = ref.read(inventoryRepositoryProvider);
    return repo.getInventoryItems();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repo = ref.read(inventoryRepositoryProvider);
    state = AsyncData(await repo.getInventoryItems());
  }

  Future<String> receiveStock({
    required String itemId,
    required String batchNumber,
    required int quantity,
    required DateTime expiryDate,
  }) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final batchId = await repo.receiveStockBatch(
      itemId: itemId,
      batchNumber: batchNumber,
      quantity: quantity,
      expiryDate: expiryDate,
    );
    await refresh();
    return batchId;
  }
}

final expiringBatchesProvider = FutureProvider<List<InventoryBatch>>((ref) async {
  final repo = ref.read(inventoryRepositoryProvider);
  return repo.getExpiringBatches(daysAhead: 30);
});

final lowStockItemsProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final repo = ref.read(inventoryRepositoryProvider);
  return repo.getLowStockItems();
});
