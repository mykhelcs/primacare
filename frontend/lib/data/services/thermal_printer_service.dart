import 'package:flutter/foundation.dart';
import '../../domain/models/invoice.dart';
import '../../domain/models/staff_profile.dart';

class ThermalPrinterService extends ChangeNotifier {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  bool _isConnected = false;
  String _connectedDeviceName = 'POS-58 Bluetooth Thermal';

  bool get isConnected => _isConnected;
  String get connectedDeviceName => _connectedDeviceName;

  void connectPrinter(String deviceName) {
    _isConnected = true;
    _connectedDeviceName = deviceName;
    notifyListeners();
  }

  void disconnectPrinter() {
    _isConnected = false;
    notifyListeners();
  }

  /// Generates ESC/POS formatted receipt text (58mm width, 32 columns)
  String generateInvoiceReceiptText({
    required Invoice invoice,
    required ClinicTenant clinic,
    required String cashierName,
  }) {
    final buffer = StringBuffer();
    final width = 32;

    String center(String text) {
      if (text.length >= width) return text.substring(0, width);
      final pad = (width - text.length) ~/ 2;
      return ' ' * pad + text;
    }

    String row(String left, String right) {
      final available = width - left.length - right.length;
      if (available <= 0) return '$left $right';
      return left + (' ' * available) + right;
    }

    final divider = '-' * width;
    final doubleDivider = '=' * width;

    // Header
    buffer.writeln(center(clinic.name.toUpperCase()));
    buffer.writeln(center(clinic.address));
    buffer.writeln(center('TIN: ${clinic.tinNumber}'));
    buffer.writeln(center('TEL: ${clinic.contactNumber}'));
    buffer.writeln(doubleDivider);
    buffer.writeln(center('OFFICIAL CLINICAL RECEIPT'));
    buffer.writeln(doubleDivider);

    // Metadata
    buffer.writeln(row('INVOICE #:', invoice.id.length > 8 ? invoice.id.substring(0, 8) : invoice.id));
    buffer.writeln(row('PATIENT:', invoice.patientName ?? 'Walk-in Patient'));
    buffer.writeln(row('CASHIER:', cashierName));
    buffer.writeln(row('DATE:', (invoice.createdAt ?? DateTime.now()).toIso8601String().split('T').first));
    buffer.writeln(divider);

    // Items
    buffer.writeln(row('ITEM', 'QTY x PRICE   TOTAL'));
    buffer.writeln(divider);

    for (final item in invoice.lineItems) {
      final lineLeft = item.itemName.length > 14 ? item.itemName.substring(0, 14) : item.itemName;
      final lineRight = '${item.quantity}x${item.unitCost.toStringAsFixed(0)} ₱${item.lineTotal.toStringAsFixed(0)}';
      buffer.writeln(row(lineLeft, lineRight));
    }

    buffer.writeln(doubleDivider);
    buffer.writeln(row('GROSS TOTAL:', '₱${invoice.grossAmount.toStringAsFixed(2)}'));
    if (invoice.hasSeniorOrPwdDiscount) {
      final label = invoice.discountType == 'senior' ? 'SENIOR (RA 9994)' : 'PWD (RA 10754)';
      if (invoice.discountIdNumber != null && invoice.discountIdNumber!.isNotEmpty) {
        buffer.writeln(row('ID #:', invoice.discountIdNumber!));
      }
      buffer.writeln(row('VAT EXEMPT (12%):', '-₱${invoice.vatExemptionAmount.toStringAsFixed(2)}'));
      buffer.writeln(row('$label 20%:', '-₱${invoice.discountAmount.toStringAsFixed(2)}'));
    } else {
      buffer.writeln(row('VAT (12% Included):', '₱${invoice.regularVatAmount.toStringAsFixed(2)}'));
      if (invoice.discountAmount > 0) {
        buffer.writeln(row('DISCOUNT:', '-₱${invoice.discountAmount.toStringAsFixed(2)}'));
      }
    }
    buffer.writeln(doubleDivider);
    buffer.writeln(row('TOTAL DUE:', '₱${invoice.netPayable.toStringAsFixed(2)}'));
    buffer.writeln(row('STATUS:', invoice.status.toUpperCase()));
    buffer.writeln(doubleDivider);

    // Footer
    buffer.writeln(center('THANK YOU FOR VISITING!'));
    buffer.writeln(center('VALID AS PROOF OF SERVICE'));
    buffer.writeln(center('*** END OF RECEIPT ***'));
    buffer.writeln('\n\n'); // ESC/POS paper feed & cut

    return buffer.toString();
  }

  /// Generates Barcode Sticky Label text for newly received batch vials
  String generateBatchBarcodeLabelText({
    required String itemName,
    required String batchNumber,
    required String barcode,
    required DateTime expiryDate,
    required ClinicTenant clinic,
  }) {
    final buffer = StringBuffer();
    final width = 28;
    final divider = '=' * width;

    buffer.writeln(divider);
    buffer.writeln('[${clinic.code}]');
    buffer.writeln('ITEM: $itemName');
    buffer.writeln('LOT#: $batchNumber');
    buffer.writeln('EXP:  ${expiryDate.toIso8601String().split('T').first}');
    buffer.writeln('BARCODE: ||| $barcode |||');
    buffer.writeln(divider);
    buffer.writeln('\n');

    return buffer.toString();
  }

  /// Simulates Bluetooth transmission of ESC/POS bytes
  Future<bool> printText(String formattedText) async {
    // Bluetooth send latency simulation
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }
}
