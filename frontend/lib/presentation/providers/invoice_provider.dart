import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/invoice.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository();
});

final openInvoicesProvider =
    AsyncNotifierProvider<OpenInvoicesNotifier, List<Invoice>>(
  OpenInvoicesNotifier.new,
);

class OpenInvoicesNotifier extends AsyncNotifier<List<Invoice>> {
  @override
  Future<List<Invoice>> build() async {
    final repo = ref.read(invoiceRepositoryProvider);
    return repo.getOpenInvoices();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repo = ref.read(invoiceRepositoryProvider);
    state = AsyncData(await repo.getOpenInvoices());
  }

  Future<DispenseResult> dispenseBarcode({
    required String barcode,
    required String invoiceId,
    int quantity = 1,
  }) async {
    final repo = ref.read(invoiceRepositoryProvider);
    final result = await repo.dispenseItem(
      barcode: barcode,
      invoiceId: invoiceId,
      quantity: quantity,
    );

    if (result.success) {
      await refresh();
      ref.invalidate(invoiceDetailProvider(invoiceId));
    }

    return result;
  }

  Future<bool> markInvoicePaid(String invoiceId) async {
    final repo = ref.read(invoiceRepositoryProvider);
    final success = await repo.markAsPaid(invoiceId);
    if (success) {
      await refresh();
      ref.invalidate(invoiceDetailProvider(invoiceId));
    }
    return success;
  }
}

final invoiceDetailProvider =
    FutureProvider.family<Invoice?, String>((ref, invoiceId) async {
  final repo = ref.read(invoiceRepositoryProvider);
  return repo.getInvoiceById(invoiceId);
});
