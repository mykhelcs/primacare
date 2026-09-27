import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/invoice.dart';
import '../services/supabase_service.dart';

class DispenseResult {
  final bool success;
  final String? message;
  final String? itemName;
  final int? quantityDispensed;
  final double? amountAdded;

  const DispenseResult({
    required this.success,
    this.message,
    this.itemName,
    this.quantityDispensed,
    this.amountAdded,
  });

  factory DispenseResult.fromJson(Map<String, dynamic> json) {
    return DispenseResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      itemName: json['item_name'] as String?,
      quantityDispensed: (json['quantity_dispensed'] as num?)?.toInt(),
      amountAdded: (json['amount_added'] as num?)?.toDouble(),
    );
  }
}

class InvoiceRepository {
  final SupabaseClient? _client;

  InvoiceRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  Future<List<Invoice>> getOpenInvoices() async {
    if (_client == null) {
      return _mockInvoices;
    }

    try {
      final response = await _client
          .from('invoices')
          .select('*, invoice_line_items(*)')
          .eq('status', 'open')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Invoice.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockInvoices;
    }
  }

  Future<DispenseResult> dispenseItem({
    required String barcode,
    required String invoiceId,
    int quantity = 1,
  }) async {
    if (_client == null) {
      // Local simulated response for offline/dev
      return DispenseResult(
        success: true,
        itemName: 'Hepatitis B Pediatric Vaccine',
        quantityDispensed: quantity,
        amountAdded: 450.0 * quantity,
      );
    }

    try {
      final response = await _client.rpc('dispense_item', params: {
        'p_barcode': barcode,
        'p_invoice_id': invoiceId,
        'p_quantity': quantity,
      });

      return DispenseResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return DispenseResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  static final List<Invoice> _mockInvoices = [
    Invoice(
      id: 'inv-1',
      patientId: 'p1',
      patientName: 'Juan Dela Cruz',
      status: 'open',
      totalAmount: 2400.0,
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      lineItems: const [
        InvoiceLineItem(
          id: 'li-1',
          invoiceId: 'inv-1',
          itemName: 'Hepatitis B Vaccine',
          quantity: 1,
          unitCost: 450.0,
        ),
        InvoiceLineItem(
          id: 'li-2',
          invoiceId: 'inv-1',
          itemName: 'Disposable Syringe 3ml',
          quantity: 2,
          unitCost: 25.0,
        ),
        InvoiceLineItem(
          id: 'li-3',
          invoiceId: 'inv-1',
          itemName: 'Consultation Fee (GP)',
          quantity: 1,
          unitCost: 1900.0,
        ),
      ],
    ),
  ];
}
