import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/inventory_provider.dart';

import '../../data/services/thermal_printer_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/access_restricted_view.dart';

class ReceiveStockScreen extends ConsumerStatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  ConsumerState<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends ConsumerState<ReceiveStockScreen> {
  final _batchController = TextEditingController();
  final _qtyController = TextEditingController();
  final _expiryController = TextEditingController();
  String? _selectedItemId;
  String _selectedItemName = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _batchController.text = 'LOT-${now.year}${now.month.toString().padLeft(2, '0')}-01';
    _expiryController.text = now.add(const Duration(days: 365)).toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _batchController.dispose();
    _qtyController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  void _showBatchLabelPreviewModal(String labelText) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Batch Label Print Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SelectableText(
            labelText,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              ThermalPrinterService().printText(labelText);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Batch barcode stickers dispatched to Bluetooth Printer!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print Labels'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final current = DateTime.tryParse(_expiryController.text) ?? DateTime.now().add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _expiryController.text = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _submitStock() async {
    if (!ref.read(currentUserRoleProvider).canReceiveStock) return;
    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity greater than 0.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_selectedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an inventory item to receive.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final expiry = DateTime.tryParse(_expiryController.text) ??
        DateTime.now().add(const Duration(days: 365));

    final batchNum = _batchController.text.isNotEmpty
        ? _batchController.text
        : 'LOT-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await ref.read(inventoryListProvider.notifier).receiveStock(
            itemId: _selectedItemId!,
            batchNumber: batchNum,
            quantity: qty,
            expiryDate: expiry,
          );
      ref.invalidate(expiringBatchesProvider);
      ref.invalidate(lowStockItemsProvider);

      if (mounted) {
        setState(() => _isLoading = false);
        final clinic = ref.read(currentClinicProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully received $qty units into batch ($batchNum)!'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Print Labels',
              textColor: Colors.white,
              onPressed: () {
                final labelText = ThermalPrinterService().generateBatchBarcodeLabelText(
                  itemName: _selectedItemName,
                  batchNumber: batchNum,
                  barcode: 'BAR-${batchNum.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
                  expiryDate: expiry,
                  clinic: clinic,
                );
                _showBatchLabelPreviewModal(labelText);
              },
            ),
          ),
        );
        _qtyController.clear();
        _batchController.text = 'LOT-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().second}';
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to receive stock: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(currentUserRoleProvider);
    if (!userRole.canReceiveStock) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: const Text(
            'Receive Inbound Stock (Add Batch)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
        body: const AccessRestrictedView(
          featureName: 'Receiving inbound warehouse stock',
          requiredRoleDescription: 'Admin or Nurse',
        ),
      );
    }

    final inventoryAsync = ref.watch(inventoryListProvider);
    final items = (inventoryAsync.value ?? [])
        .where((i) => i.category != 'Services')
        .toList();

    if (_selectedItemId == null && items.isNotEmpty) {
      _selectedItemId = items.first.id;
      _selectedItemName = items.first.name;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Receive Inbound Stock (Add Batch)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select Inventory Item from Clinic Formulary',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedItemId,
                isExpanded: true,
                items: items
                    .map((item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            '${item.name} (${item.category} · ${item.unit})',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    final found = items.where((i) => i.id == val).firstOrNull;
                    if (found != null) {
                      setState(() {
                        _selectedItemId = val;
                        _selectedItemName = found.name;
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Batch / Lot Number',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _batchController,
                decoration: const InputDecoration(hintText: 'e.g. HB-2026-09'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quantity Received',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'e.g. 50'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Expiry Date (YYYY-MM-DD)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _expiryController,
                readOnly: true,
                onTap: _pickExpiryDate,
                decoration: const InputDecoration(
                  hintText: 'e.g. 2027-10-31',
                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Batch to Inventory'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
