import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/status_badge.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  String _selectedCategory = 'All';

  final List<Map<String, dynamic>> _items = [
    {
      'name': 'Hepatitis B Vaccine 0.5ml',
      'barcode': '4800016552011',
      'category': 'Vaccines',
      'stock': 24,
      'unit': 'vials',
      'cost': 450.0,
      'reorder': 10,
    },
    {
      'name': 'MMR (Measles, Mumps, Rubella)',
      'barcode': '4800016552012',
      'category': 'Vaccines',
      'stock': 6,
      'unit': 'vials',
      'cost': 720.0,
      'reorder': 10,
    },
    {
      'name': 'Disposable Syringe 3ml',
      'barcode': '4800016552022',
      'category': 'Consumables',
      'stock': 120,
      'unit': 'pcs',
      'cost': 25.0,
      'reorder': 50,
    },
    {
      'name': 'Sterile Cotton Balls 100s',
      'barcode': '4800016552023',
      'category': 'Consumables',
      'stock': 8,
      'unit': 'packs',
      'cost': 45.0,
      'reorder': 15,
    },
    {
      'name': 'Paracetamol 500mg Tablets',
      'barcode': '4800016552033',
      'category': 'Pharmaceuticals',
      'stock': 250,
      'unit': 'tabs',
      'cost': 5.50,
      'reorder': 100,
    },
    {
      'name': 'Amoxicillin 500mg Caps',
      'barcode': '4800016552034',
      'category': 'Pharmaceuticals',
      'stock': 14,
      'unit': 'caps',
      'cost': 12.0,
      'reorder': 30,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == 'All'
        ? _items
        : _items.where((i) => i['category'] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Inventory Catalog',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Vaccines', 'Consumables', 'Pharmaceuticals'].map((cat) {
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                final isLowStock = (item['stock'] as int) <= (item['reorder'] as int);

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
                              item['name'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Barcode: ${item['barcode']} · Unit Cost: ₱${(item['cost'] as double).toStringAsFixed(2)}',
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
                            '${item['stock']} ${item['unit']}',
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
    );
  }
}
