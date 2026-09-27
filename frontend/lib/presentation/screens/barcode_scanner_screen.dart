import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../providers/invoice_provider.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  final VoidCallback? onDispensed;

  const BarcodeScannerScreen({
    super.key,
    this.invoiceId = 'inv-1',
    this.onDispensed,
  });

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  String _currentBarcode = '4800016552011';
  String _itemName = 'Hepatitis B Pediatric Vaccine';
  String _batchNumber = 'HB-2026-04 (FIFO)';
  String _expiry = 'Exp: 24 Oct 2026 (28 days left)';
  double _unitCost = 450.0;
  int _quantity = 1;
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null && barcode != _currentBarcode) {
      setState(() {
        _currentBarcode = barcode;
        _itemName = 'Scanned Item ($barcode)';
        _batchNumber = 'Oldest Non-Expired Batch';
        _expiry = 'Valid';
      });
    }
  }

  void _selectMockItem(String name, String barcode, String batch, String exp, double cost) {
    setState(() {
      _itemName = name;
      _currentBarcode = barcode;
      _batchNumber = batch;
      _expiry = exp;
      _unitCost = cost;
      _quantity = 1;
    });
  }

  Future<void> _confirmDispense() async {
    setState(() => _isProcessing = true);

    try {
      final result = await ref.read(openInvoicesProvider.notifier).dispenseBarcode(
            barcode: _currentBarcode,
            invoiceId: widget.invoiceId,
            quantity: _quantity,
          );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully dispensed $_quantity × ${result.itemName ?? _itemName} to invoice!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onDispensed?.call();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Dispense failed.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        title: const Text(
          'Point at Barcode',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Viewfinder
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!kIsWeb &&
                    (defaultTargetPlatform == TargetPlatform.android ||
                        defaultTargetPlatform == TargetPlatform.iOS))
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                  )
                else
                  Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Text(
                      'Camera Scanner Active\n(Simulate below for testing/desktop)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),

                // Targeting Reticle
                Center(
                  child: Container(
                    width: 250,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accent, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 2,
                          color: AppColors.danger,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Barcode: $_currentBarcode',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Simulation chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Simulate: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ActionChip(
                    label: const Text('Hep B Vaccine'),
                    onPressed: () => _selectMockItem(
                      'Hepatitis B Pediatric Vaccine',
                      '4800016552011',
                      'HB-2026-04 (FIFO)',
                      'Exp: 24 Oct 2026 (28 days left)',
                      450.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Syringe 3ml'),
                    onPressed: () => _selectMockItem(
                      'Disposable Syringe 3ml',
                      '4800016552022',
                      'SY-2026-11 (FIFO)',
                      'Exp: 15 Jun 2027',
                      25.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Paracetamol'),
                    onPressed: () => _selectMockItem(
                      'Paracetamol 500mg Tab',
                      '4800016552033',
                      'PC-2026-09 (FIFO)',
                      'Exp: 30 Dec 2026',
                      5.50,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dispense Action Panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _itemName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '₱${(_unitCost * _quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _batchNumber,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _expiry,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dispense Quantity',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: AppColors.primary,
                            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.primary,
                            onPressed: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmDispense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Confirm Dispensation & Add to Invoice',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
