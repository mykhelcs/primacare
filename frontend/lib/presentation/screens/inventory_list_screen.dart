import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/inventory_provider.dart';
import '../widgets/status_badge.dart';
import 'barcode_catalog_screen.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  String _selectedCategory = 'All';

  String _generateBarcode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final suffix = (timestamp % 100000000).toString().padLeft(8, '0');
    return '48000$suffix';
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController(text: _generateBarcode());
    final unitCtrl = TextEditingController(text: 'vial');
    final costCtrl = TextEditingController(text: '100');
    final reorderCtrl = TextEditingController(text: '10');
    String category = 'Vaccines';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add Catalog Formulary Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name *', hintText: 'e.g. Tetanus Toxoid Vaccine'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['Vaccines', 'Consumables', 'Pharmaceuticals', 'Services']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'Unit', hintText: 'e.g. vial / pcs / box'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Unit Cost (₱)', prefixText: '₱ '),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: barcodeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Barcode Number (Auto-Generated)',
                    hintText: 'e.g. 4800016552099',
                    prefixIcon: const Icon(Icons.qr_code, size: 18),
                    suffixIcon: IconButton(
                      tooltip: 'Regenerate Barcode',
                      icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                      onPressed: () {
                        setModalState(() {
                          barcodeCtrl.text = _generateBarcode();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reorderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reorder Level Threshold'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                if (name.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  await ref.read(inventoryListProvider.notifier).createItem(
                        name: name,
                        barcode: barcodeCtrl.text.trim().isNotEmpty
                            ? barcodeCtrl.text.trim()
                            : '48000${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                        unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'unit',
                        unitCost: cost,
                        category: category,
                        reorderLevel: int.tryParse(reorderCtrl.text.trim()) ?? 10,
                      );
                  messenger.showSnackBar(
                    SnackBar(content: Text('Added $name to catalog!'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Add to Formulary'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryListProvider);
    final allItems = inventoryAsync.value ?? [];

    final filtered = _selectedCategory == 'All'
        ? allItems
        : allItems.where((i) => i.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Inventory Formulary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Barcode & QR Catalog',
            icon: const Icon(Icons.qr_code_2, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeCatalogScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Add Catalog Item',
            icon: const Icon(Icons.add_box, color: AppColors.primary),
            onPressed: _showAddItemDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(inventoryListProvider.notifier).refresh(),
        color: AppColors.primary,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Vaccines', 'Consumables', 'Pharmaceuticals', 'Services'].map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppColors.primaryLight,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: inventoryAsync.isLoading && allItems.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 60),
                            Center(
                              child: Text(
                                'No inventory items in this category.\nPull down to refresh from Supabase.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isLowStock = item.isLowStock;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Barcode: ${item.barcode ?? 'N/A'} · Unit Cost: ₱${item.unitCost.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.totalStock} ${item.unit}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isLowStock ? AppColors.danger : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (isLowStock)
                                        StatusBadge.warning(text: 'Low Stock')
                                      else
                                        StatusBadge.open(),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
