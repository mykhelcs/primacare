import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/invoice.dart';
import '../services/supabase_service.dart';
import 'inventory_repository.dart';

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
      return [];
    }
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<Invoice?> getInvoiceById(String id) async {
    if (_client == null) {
      final found = _mockInvoices.where((i) => i.id == id);
      return found.isNotEmpty ? found.first : (_mockInvoices.isNotEmpty ? _mockInvoices.first : null);
    }
    if (!_uuidRegex.hasMatch(id)) {
      return null;
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
      return null;
    }
  }

  Future<Invoice> createInvoice({
    required String patientId,
    String? patientName,
  }) async {
    if (_client == null) {
      final newInv = Invoice(
        id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
        patientId: patientId,
        patientName: patientName ?? 'Patient $patientId',
        status: 'open',
        totalAmount: 0.0,
        createdAt: DateTime.now(),
        lineItems: const [],
      );
      _mockInvoices.insert(0, newInv);
      return newInv;
    }

    try {
      final response = await _client
          .from('invoices')
          .insert({
            'patient_id': patientId,
            'status': 'open',
            'total_amount': 0.00,
          })
          .select('*, invoice_line_items(*), patients(full_name)')
          .single();

      final map = Map<String, dynamic>.from(response);
      if (map['patients'] != null && map['patients'] is Map) {
        map['patient_name'] = map['patients']['full_name'];
      }
      return Invoice.fromJson(map);
    } catch (_) {
      final fallback = Invoice(
        id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
        patientId: patientId,
        patientName: patientName ?? 'Patient $patientId',
        status: 'open',
        totalAmount: 0.0,
        createdAt: DateTime.now(),
        lineItems: const [],
      );
      _mockInvoices.insert(0, fallback);
      return fallback;
    }
  }

  Future<Invoice?> addServiceItem({
    required String invoiceId,
    required String serviceName,
    required double fee,
  }) async {
    if (_client == null) {
      final idx = _mockInvoices.indexWhere((i) => i.id == invoiceId);
      if (idx != -1) {
        final old = _mockInvoices[idx];
        if (old.isPaid) return null;
        final updatedLines = [
          ...old.lineItems,
          InvoiceLineItem(
            id: 'li_${DateTime.now().millisecondsSinceEpoch}',
            invoiceId: invoiceId,
            itemName: serviceName,
            quantity: 1,
            unitCost: fee,
          ),
        ];
        final updated = old.copyWith(
          totalAmount: old.totalAmount + fee,
          lineItems: updatedLines,
        );
        _mockInvoices[idx] = updated;
        return updated;
      }
      return null;
    }

    try {
      final current = await getInvoiceById(invoiceId);
      if (current == null || current.isPaid) return null;

      await _client.from('invoice_line_items').insert({
        'invoice_id': invoiceId,
        'item_name': serviceName,
        'quantity': 1,
        'unit_cost': fee,
      });

      // Recalculate invoice total
      final totalRes = await _client
          .from('invoice_line_items')
          .select('unit_cost, quantity')
          .eq('invoice_id', invoiceId);
      double newTotal = 0.0;
      for (final row in totalRes as List) {
        final q = (row['quantity'] as num?)?.toInt() ?? 1;
        final c = (row['unit_cost'] as num?)?.toDouble() ?? 0.0;
        newTotal += (q * c);
      }

      await _client
          .from('invoices')
          .update({'total_amount': newTotal})
          .eq('id', invoiceId);

      return await getInvoiceById(invoiceId);
    } catch (_) {
      return getInvoiceById(invoiceId);
    }
  }

  Future<bool> markAsPaid(
    String invoiceId, {
    String paymentMethod = 'Cash',
  }) async {
    final now = DateTime.now();
    if (_client == null) {
      final idx = _mockInvoices.indexWhere((i) => i.id == invoiceId);
      if (idx == -1) return false;
      final old = _mockInvoices[idx];
      if (old.isPaid) return false;
      _mockInvoices[idx] = old.copyWith(
        status: 'paid',
        paymentMethod: paymentMethod,
        paidAt: now,
      );
      return true;
    }

    try {
      await _client.from('invoices').update({
        'status': 'paid',
        'payment_method': paymentMethod,
        'paid_at': now.toUtc().toIso8601String(),
      }).eq('id', invoiceId);
      return true;
    } on PostgrestException catch (e) {
      // Fallback if remote schema has not yet added payment audit columns
      if (e.message.contains('payment_method') || e.message.contains('paid_at')) {
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
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Invoice?> applyDiscount({
    required String invoiceId,
    required String discountType, // 'none' | 'senior' | 'pwd' | 'custom'
    double percentage = 20.0,
    String? discountIdNumber,
  }) async {
    if (_client != null && _uuidRegex.hasMatch(invoiceId)) {
      final current = await getInvoiceById(invoiceId);
      if (current == null || current.isPaid) return null;
      await _client.from('invoices').update({
        'discount_type': discountType,
        'discount_percentage': discountType == 'none' ? 0.0 : percentage,
        'discount_id_number': discountIdNumber,
      }).eq('id', invoiceId);
      return await getInvoiceById(invoiceId);
    }

    final idx = _mockInvoices.indexWhere((i) => i.id == invoiceId);
    if (idx != -1) {
      final old = _mockInvoices[idx];
      if (old.isPaid) return null;
      final updated = old.copyWith(
        discountType: discountType,
        discountPercentage: discountType == 'none' ? 0.0 : percentage,
        discountIdNumber: discountIdNumber,
      );
      _mockInvoices[idx] = updated;
      return updated;
    }
    return null;
  }

  Future<DispenseResult> dispenseItem({
    required String barcode,
    required String invoiceId,
    int quantity = 1,
  }) async {
    // 0. Boundary & Pentest Defense: Guard against non-positive quantity and blank barcode
    if (quantity < 1) {
      return const DispenseResult(
        success: false,
        message: 'Dispense quantity must be at least 1.',
      );
    }
    final sanitizedBarcode = barcode.trim();
    if (sanitizedBarcode.isEmpty) {
      return const DispenseResult(
        success: false,
        message: 'Barcode cannot be empty.',
      );
    }

    // 1. Live Supabase RPC path
    if (_client != null) {
      if (!_uuidRegex.hasMatch(invoiceId)) {
        return const DispenseResult(
          success: false,
          message: 'No active live invoice selected. Please create or open a patient invoice first.',
        );
      }
      try {
        final response = await _client.rpc('dispense_item', params: {
          'p_barcode': sanitizedBarcode,
          'p_invoice_id': invoiceId,
          'p_quantity': quantity,
        });

        if (response is Map<String, dynamic>) {
          return DispenseResult.fromJson(response);
        }
        return const DispenseResult(
          success: false,
          message: 'Unexpected response from dispensation service.',
        );
      } on PostgrestException catch (e) {
        return DispenseResult(
          success: false,
          message: 'Database error during dispensation: ${e.message}',
        );
      } catch (e) {
        return DispenseResult(
          success: false,
          message: 'Network or server error during dispensation: $e',
        );
      }
    }

    // 2. Local Item-Aware FEFO Dispensation (mock / test mode)
    final invIndex = _mockInvoices.indexWhere((i) => i.id == invoiceId);
    if (invIndex != -1 && _mockInvoices[invIndex].isPaid) {
      return const DispenseResult(
        success: false,
        message: 'Cannot dispense items onto an already paid invoice.',
      );
    }

    final invRepo = InventoryRepository(client: _client);
    final item = await invRepo.getItemByBarcode(sanitizedBarcode);
    if (item != null &&
        item.category.toLowerCase() != 'services' &&
        item.totalStock < quantity) {
      return DispenseResult(
        success: false,
        message: 'Insufficient stock for ${item.name} (${item.totalStock} available, $quantity requested).',
      );
    }

    final itemName = item?.name ?? 'Clinical Item ($sanitizedBarcode)';
    final unitCost = item?.unitCost ?? 150.0;
    final addedTotal = unitCost * quantity;

    if (item != null && item.category.toLowerCase() != 'services') {
      final deducted = await invRepo.dispenseItemFEFO(itemId: item.id, quantity: quantity);
      if (!deducted) {
        return DispenseResult(
          success: false,
          message: 'Insufficient unexpired batch stock for ${item.name}.',
        );
      }
    }

    if (invIndex != -1) {
      final old = _mockInvoices[invIndex];
      final updatedLines = [
        ...old.lineItems,
        InvoiceLineItem(
          id: 'li_${DateTime.now().millisecondsSinceEpoch}',
          invoiceId: invoiceId,
          itemName: itemName,
          quantity: quantity,
          unitCost: unitCost,
        ),
      ];
      _mockInvoices[invIndex] = old.copyWith(
        totalAmount: old.totalAmount + addedTotal,
        lineItems: updatedLines,
      );
    }

    return DispenseResult(
      success: true,
      itemName: itemName,
      quantityDispensed: quantity,
      amountAdded: addedTotal,
    );
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
