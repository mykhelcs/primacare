import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../providers/invoice_provider.dart';
import '../../data/services/offline_sync_service.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final String? invoiceId;
  final VoidCallback? onDispensed;

  const BarcodeScannerScreen({
    super.key,
    this.invoiceId,
    this.onDispensed,
  });

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  String _currentBarcode = '4800016552011';
  InventoryItem? _scannedItem;
  int _quantity = 1;
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _lookupBarcode(_currentBarcode);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _lookupBarcode(String barcode) async {
    setState(() => _currentBarcode = barcode);
    final repo = ref.read(inventoryRepositoryProvider);
    final item = await repo.getItemByBarcode(barcode);
    if (mounted) {
      setState(() {
        _scannedItem = item ??
            InventoryItem(
              id: 'unknown',
              name: 'Item ($barcode)',
              barcode: barcode,
              unitCost: 150.00,
            );
        _quantity = 1;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null && barcode != _currentBarcode) {
      _lookupBarcode(barcode);
    }
  }

  Future<void> _confirmDispense(String targetInvoiceId) async {
    setState(() => _isProcessing = true);

    final isOnline = OfflineSyncService().isOnline;
    if (!isOnline) {
      OfflineSyncService().enqueueAction(
        type: SyncActionType.dispenseItem,
        payload: {
          'barcode': _currentBarcode,
          'invoiceId': targetInvoiceId,
          'quantity': _quantity,
        },
      );
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Offline Mode: Dispensation of $_quantity × ${_scannedItem?.name} queued for sync!',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onDispensed?.call();
        });
      }
      return;
    }

    try {
      final result = await ref.read(openInvoicesProvider.notifier).dispenseBarcode(
            barcode: _currentBarcode,
            invoiceId: targetInvoiceId,
            quantity: _quantity,
          );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully dispensed $_quantity × ${result.itemName ?? _scannedItem?.name} to Invoice #$targetInvoiceId!',
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
    final openInvoices = ref.watch(openInvoicesProvider).value ?? [];
    final activeInvoiceId = widget.invoiceId ??
        (openInvoices.isNotEmpty ? openInvoices.first.id : 'inv-1');

    final itemName = _scannedItem?.name ?? 'Loading item...';
    final unitCost = _scannedItem?.unitCost ?? 0.0;
    final totalCost = unitCost * _quantity;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        title: const Text(
          'Point Camera at Barcode',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () {
              _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
          const SizedBox(width: 8),
        ],
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
                      'Camera Viewfinder\n(Mobile camera active on device)',
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
                      'Target Invoice: #$activeInvoiceId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Simulation chips for testing without physical barcodes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Quick Test: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ActionChip(
                    label: const Text('Hep B Vaccine'),
                    onPressed: () => _lookupBarcode('4800016552011'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Syringe 3ml'),
                    onPressed: () => _lookupBarcode('4800016552022'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Paracetamol'),
                    onPressed: () => _lookupBarcode('4800016552033'),
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
                          itemName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '₱${totalCost.toStringAsFixed(2)}',
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
                        child: const Text(
                          'FIFO Automatic Batch Allocation',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Barcode: $_currentBarcode',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
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
                    onPressed: _isProcessing ? null : () => _confirmDispense(activeInvoiceId),
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
                        : Text(
                            'Confirm Dispensation & Append to Bill',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
