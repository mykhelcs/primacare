import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/inventory_item.dart';
import '../../domain/models/invoice.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/invoice_provider.dart';
import '../../data/services/offline_sync_service.dart';

/// Deterministic hardware & camera barcode debounce controller.
/// Clinic laser/USB scanners and mobile cameras often emit duplicate reads
/// within 50–200ms. This guard enforces a strict cooldown window (default 250ms)
/// to prevent accidental double-lookup or double-billing.
class BarcodeHardwareDebouncer {
  final Duration cooldown;
  String? _lastBarcode;
  DateTime? _lastScanAt;
  DateTime? _lastDispenseAt;

  BarcodeHardwareDebouncer({
    this.cooldown = const Duration(milliseconds: 250),
  });

  /// Returns `true` if [barcode] should be processed at [now], or `false` if it
  /// falls within the hardware debounce cooldown window for the same barcode.
  bool shouldAcceptScan(String barcode, {DateTime? now}) {
    final clean = barcode.trim();
    if (clean.isEmpty) return false;
    final timestamp = now ?? DateTime.now();

    if (_lastBarcode == clean &&
        _lastScanAt != null &&
        timestamp.difference(_lastScanAt!) < cooldown) {
      return false;
    }

    _lastBarcode = clean;
    _lastScanAt = timestamp;
    return true;
  }

  /// Guards the dispensation action against rapid double-taps or hardware
  /// scanner Enter-key bounce within the cooldown window.
  bool shouldAcceptDispense({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    if (_lastDispenseAt != null &&
        timestamp.difference(_lastDispenseAt!) < cooldown) {
      return false;
    }
    _lastDispenseAt = timestamp;
    return true;
  }
}

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
  final TextEditingController _barcodeInputController = TextEditingController();
  final BarcodeHardwareDebouncer _debouncer = BarcodeHardwareDebouncer(
    cooldown: const Duration(milliseconds: 250),
  );

  String _currentBarcode = '';
  InventoryItem? _scannedItem;
  int _quantity = 1;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _barcodeInputController.dispose();
    super.dispose();
  }

  void _showNurseAlert(String message, {required Color backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showFormularySearchModal() {
    final inventory = (ref.read(inventoryListProvider).value ?? [])
        .where((i) => i.category.toLowerCase() != 'services')
        .toList();

    String filterQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final filtered = inventory.where((i) {
            if (filterQuery.isEmpty) return true;
            final q = filterQuery.toLowerCase();
            return i.name.toLowerCase().contains(q) ||
                (i.barcode?.toLowerCase().contains(q) ?? false) ||
                i.category.toLowerCase().contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Select from Clinic Formulary',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search drug, vaccine, or consumable name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) {
                    setModalState(() => filterQuery = val.trim());
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No items match your search.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 8),
                          itemBuilder: (context, idx) {
                            final item = filtered[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              title: Text(
                                item.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              subtitle: Text(
                                '${item.category} · Barcode: ${item.barcode ?? 'N/A'} · Stock: ${item.totalStock} ${item.unit}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${item.unitCost.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('Tap to Select', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                if (item.barcode != null && item.barcode!.isNotEmpty) {
                                  _lookupBarcode(item.barcode!, bypassDebounce: true);
                                } else {
                                  setState(() {
                                    _scannedItem = item;
                                    _currentBarcode = item.barcode ?? 'ITEM-${item.id}';
                                    _quantity = 1;
                                    _errorMessage = null;
                                  });
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _lookupBarcode(String barcode, {bool bypassDebounce = false}) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty || _isProcessing) return;

    // Hardware Debounce: reject duplicate reads within the 250ms cooldown window
    if (!bypassDebounce && !_debouncer.shouldAcceptScan(cleanBarcode)) {
      return;
    }

    setState(() {
      _currentBarcode = cleanBarcode;
      _errorMessage = null;
    });
    if (_barcodeInputController.text != cleanBarcode) {
      _barcodeInputController.text = cleanBarcode;
    }

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final item = await repo.getItemByBarcode(cleanBarcode);
      if (!mounted) return;

      setState(() {
        _scannedItem = item;
        _quantity = 1;
        _errorMessage = item == null
            ? 'Item with barcode "$cleanBarcode" not found in clinic formulary.'
            : null;
      });

      if (item == null) {
        _showNurseAlert(
          'Item with barcode "$cleanBarcode" not found in clinic formulary.',
          backgroundColor: AppColors.warning,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errMsg = 'Unable to lookup barcode "$cleanBarcode". Please check network connection.';
      setState(() {
        _scannedItem = null;
        _errorMessage = errMsg;
      });
      _showNurseAlert(errMsg, backgroundColor: AppColors.danger);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;
    final clean = barcode.trim();
    if (clean.isEmpty) return;

    // Enforce hardware debounce on camera frames
    if (!_debouncer.shouldAcceptScan(clean)) return;
    if (clean != _currentBarcode || _scannedItem == null) {
      _lookupBarcode(clean, bypassDebounce: true);
    }
  }

  Future<void> _confirmDispense(String targetInvoiceId) async {
    if (_isProcessing) return;

    // Hardware & UI Cooldown: block rapid duplicate dispense triggers (<250ms)
    if (!_debouncer.shouldAcceptDispense()) {
      return;
    }

    if (_quantity < 1) {
      _showNurseAlert(
        'Dispense quantity must be at least 1.',
        backgroundColor: AppColors.danger,
      );
      return;
    }

    // Pre-flight stock validation for physical inventory items
    final item = _scannedItem;
    if (item != null &&
        item.category.toLowerCase() != 'services' &&
        item.totalStock < _quantity) {
      final msg =
          'Dispensation failed: Insufficient stock for ${item.name} (${item.totalStock} ${item.unit} available).';
      setState(() => _errorMessage = msg);
      _showNurseAlert(msg, backgroundColor: AppColors.danger);
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

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
        _showNurseAlert(
          'Offline Mode: Dispensation of $_quantity × ${_scannedItem?.name} queued for sync!',
          backgroundColor: AppColors.warning,
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
        setState(() => _errorMessage = null);
        _showNurseAlert(
          'Successfully dispensed $_quantity × ${result.itemName ?? _scannedItem?.name} to Invoice #$targetInvoiceId!',
          backgroundColor: AppColors.success,
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onDispensed?.call();
        });
      } else {
        final failMsg =
            'Dispensation failed: ${result.message ?? 'Out of stock or concurrent update conflict.'}';
        setState(() => _errorMessage = failMsg);
        _showNurseAlert(failMsg, backgroundColor: AppColors.danger);
      }
    } catch (e) {
      if (!mounted) return;
      final failMsg =
          'Dispensation failed: Unable to complete transaction (${e.toString().replaceAll('Exception: ', '')}). Please verify stock and try again.';
      setState(() => _errorMessage = failMsg);
      _showNurseAlert(failMsg, backgroundColor: AppColors.danger);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openInvoices = ref.watch(openInvoicesProvider).value ?? [];
    final unclosedInvoices = openInvoices.where((inv) => inv.isOpen).toList();
    Invoice? activeInvoice;
    if (widget.invoiceId != null) {
      for (final inv in unclosedInvoices) {
        if (inv.id == widget.invoiceId) {
          activeInvoice = inv;
          break;
        }
      }
    }
    activeInvoice ??=
        unclosedInvoices.isNotEmpty ? unclosedInvoices.first : null;
    final activeInvoiceId = activeInvoice?.id;
    final isMobileCameraSupported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    final itemName = _scannedItem?.name ??
        (_currentBarcode.isEmpty ? 'Ready to Scan Barcode' : 'Item Not Found in Formulary');
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
            tooltip: 'Search Formulary Catalog',
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showFormularySearchModal,
          ),
          if (isMobileCameraSupported) ...[
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
          ],
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
                  top: 16,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87.withValues(alpha: 0.85),
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text(
                      "Can't scan? Search Formulary Catalog",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _showFormularySearchModal,
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

          // USB Barcode Scanner Gun & Manual Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black87,
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _barcodeInputController,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: 'USB Scanner Gun or Enter Barcode...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _lookupBarcode(val.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    final val = _barcodeInputController.text.trim();
                    if (val.isNotEmpty) _lookupBarcode(val);
                  },
                  child: const Text('Lookup', style: TextStyle(fontSize: 12, color: Colors.white)),
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
                  ActionChip(
                    avatar: const Icon(Icons.search, size: 14, color: AppColors.accent),
                    label: const Text('Search Catalog...', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _showFormularySearchModal,
                  ),
                  const SizedBox(width: 8),
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
                  if (_errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    onPressed: (_isProcessing ||
                            activeInvoiceId == null ||
                            _scannedItem == null ||
                            !ref.watch(currentUserRoleProvider).canDispense)
                        ? null
                        : () => _confirmDispense(activeInvoiceId),
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
                            !ref.watch(currentUserRoleProvider).canDispense
                                ? 'Dispensation Restricted (Nurse / Admin Only)'
                                : (activeInvoiceId == null
                                    ? 'No Active Encounter (Start an Encounter First)'
                                    : (_scannedItem == null
                                        ? 'Scan or Select Item to Dispense'
                                        : 'Confirm Dispensation & Append to Bill')),
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
