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
          .select('*, invoice_line_items(*), patients(full_name)')
          .order('created_at', ascending: false);

      return (response as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        if (map['patients'] != null && map['patients'] is Map) {
          map['patient_name'] = map['patients']['full_name'];
        }
        return Invoice.fromJson(map);
      }).toList();
    } catch (_) {
      return _mockInvoices;
    }
  }

  Future<Invoice?> getInvoiceById(String id) async {
    if (_client == null) {
      final found = _mockInvoices.where((i) => i.id == id);
      return found.isNotEmpty ? found.first : _mockInvoices.first;
    }

    try {
      final response = await _client
          .from('invoices')
          .select('*, invoice_line_items(*), patients(full_name)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      final map = Map<String, dynamic>.from(response);
      if (map['patients'] != null && map['patients'] is Map) {
        map['patient_name'] = map['patients']['full_name'];
      }
      return Invoice.fromJson(map);
    } catch (_) {
      final found = _mockInvoices.where((i) => i.id == id);
      return found.isNotEmpty ? found.first : _mockInvoices.first;
    }
  }

  Future<bool> markAsPaid(String invoiceId) async {
    if (_client == null) {
      final idx = _mockInvoices.indexWhere((i) => i.id == invoiceId);
      if (idx != -1) {
        final old = _mockInvoices[idx];
        _mockInvoices[idx] = Invoice(
          id: old.id,
          patientId: old.patientId,
          patientName: old.patientName,
          status: 'paid',
          totalAmount: old.totalAmount,
          createdAt: old.createdAt,
          lineItems: old.lineItems,
        );
      }
      return true;
    }

    try {
      await _client
          .from('invoices')
          .update({'status': 'paid'})
          .eq('id', invoiceId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DispenseResult> dispenseItem({
    required String barcode,
    required String invoiceId,
    int quantity = 1,
  }) async {
    if (_client == null) {
      // Local simulated response for offline/dev
      final invIndex = _mockInvoices.indexWhere((i) => i.id == invoiceId);
      final addedTotal = 450.0 * quantity;
      if (invIndex != -1) {
        final old = _mockInvoices[invIndex];
        final updatedLines = [
          ...old.lineItems,
          InvoiceLineItem(
            id: 'li_${DateTime.now().millisecondsSinceEpoch}',
            invoiceId: invoiceId,
            itemName: 'Hepatitis B Pediatric Vaccine',
            quantity: quantity,
            unitCost: 450.0,
          ),
        ];
        _mockInvoices[invIndex] = Invoice(
          id: old.id,
          patientId: old.patientId,
          patientName: old.patientName,
          status: old.status,
          totalAmount: old.totalAmount + addedTotal,
          createdAt: old.createdAt,
          lineItems: updatedLines,
        );
      }

      return DispenseResult(
        success: true,
        itemName: 'Hepatitis B Pediatric Vaccine',
        quantityDispensed: quantity,
        amountAdded: addedTotal,
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
