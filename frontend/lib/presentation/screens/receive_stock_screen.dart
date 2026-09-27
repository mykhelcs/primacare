import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/inventory_provider.dart';

import '../../data/services/thermal_printer_service.dart';
import '../providers/auth_provider.dart';

class ReceiveStockScreen extends ConsumerStatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  ConsumerState<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends ConsumerState<ReceiveStockScreen> {
  final _batchController = TextEditingController();
  final _qtyController = TextEditingController();
  final _expiryController = TextEditingController();
  String _selectedItem = 'Hepatitis B Pediatric Vaccine';
  bool _isLoading = false;

  @override
  void dispose() {
    _batchController.dispose();
    _qtyController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _submitStock() async {
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

    setState(() => _isLoading = true);
    final expiry = DateTime.tryParse(_expiryController.text) ??
        DateTime.now().add(const Duration(days: 365));

    final batchNum = _batchController.text.isNotEmpty
        ? _batchController.text
        : 'LOT-${DateTime.now().millisecondsSinceEpoch}';

    final repo = ref.read(inventoryRepositoryProvider);
    final batchId = await repo.receiveStockBatch(
      itemId: 'i1',
      batchNumber: batchNum,
      quantity: qty,
      expiryDate: expiry,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      final clinic = ref.read(currentClinicProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully received $qty units into batch ($batchId)!'),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'Print Labels',
            textColor: Colors.white,
            onPressed: () {
              final labelText = ThermalPrinterService().generateBatchBarcodeLabelText(
                itemName: _selectedItem,
                batchNumber: batchNum,
                barcode: 'BAR-${batchNum.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
                expiryDate: expiry,
                clinic: clinic,
              );
              ThermalPrinterService().printText(labelText);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Batch barcode stickers dispatched to Bluetooth Printer!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ),
      );
      _batchController.clear();
      _qtyController.clear();
      _expiryController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Receive Stock (Add Batch)',
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
                'Select Inventory Item',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedItem,
                items: [
                  'Hepatitis B Pediatric Vaccine',
                  'MMR Pediatric Vaccine',
                  'Disposable Syringe 3ml',
                  'Paracetamol 500mg Tablets',
                ]
                    .map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedItem = val!),
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
                decoration: const InputDecoration(hintText: 'e.g. 2027-10-31'),
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
