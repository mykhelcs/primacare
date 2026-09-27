import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/thermal_printer_service.dart';
import '../../domain/models/invoice.dart';
import '../../domain/models/staff_profile.dart';

class ReceiptPreviewDialog extends StatefulWidget {
  final Invoice invoice;
  final ClinicTenant clinic;
  final String cashierName;

  const ReceiptPreviewDialog({
    super.key,
    required this.invoice,
    required this.clinic,
    required this.cashierName,
  });

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  final _printerService = ThermalPrinterService();
  bool _isPrinting = false;
  late String _receiptText;

  @override
  void initState() {
    super.initState();
    _receiptText = _printerService.generateInvoiceReceiptText(
      invoice: widget.invoice,
      clinic: widget.clinic,
      cashierName: widget.cashierName,
    );
  }

  void _printReceipt() async {
    setState(() => _isPrinting = true);
    final success = await _printerService.printText(_receiptText);
    if (mounted) {
      setState(() => _isPrinting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt sent to ${_printerService.connectedDeviceName}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.print, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Thermal Receipt Preview',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_connected, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Target: ${_printerService.connectedDeviceName}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _receiptText,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      height: 1.3,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isPrinting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.print),
                label: Text(_isPrinting ? 'Printing to Bluetooth...' : 'Print ESC/POS Slip'),
                onPressed: _isPrinting ? null : _printReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
