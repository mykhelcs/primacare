import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../domain/models/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository();
});

final inventoryListProvider = AsyncNotifierProvider<InventoryListNotifier, List<InventoryItem>>(
  InventoryListNotifier.new,
);

class InventoryListNotifier extends AsyncNotifier<List<InventoryItem>> {
  @override
  Future<List<InventoryItem>> build() async {
    final repo = ref.read(inventoryRepositoryProvider);
    return repo.getInventoryItems();
  }
}
