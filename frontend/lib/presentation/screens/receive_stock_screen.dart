import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ReceiveStockScreen extends StatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  State<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends State<ReceiveStockScreen> {
  final _batchController = TextEditingController();
  final _qtyController = TextEditingController();
  final _expiryController = TextEditingController();
  String _selectedItem = 'Hepatitis B Pediatric Vaccine';

  @override
  void dispose() {
    _batchController.dispose();
    _qtyController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  void _submitStock() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Received ${_qtyController.text} units into batch ${_batchController.text}!'),
        backgroundColor: AppColors.success,
      ),
    );
    _batchController.clear();
    _qtyController.clear();
    _expiryController.clear();
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
                onPressed: _submitStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Add Batch to Inventory'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
