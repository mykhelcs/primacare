import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/invoice.dart';
import '../../domain/models/inventory_item.dart';
import '../providers/invoice_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/status_badge.dart';
import '../widgets/receipt_preview_dialog.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  final VoidCallback? onScanMore;

  const InvoiceDetailScreen({
    super.key,
    this.invoiceId = 'inv-1',
    this.onScanMore,
  });

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _isProcessing = false;

  void _showAddServiceDialog() {
    final customNameCtrl = TextEditingController();
    final customFeeCtrl = TextEditingController(text: '500');

    final standardServices = [
      {'name': 'General Medical Consultation', 'fee': 500.0},
      {'name': 'Pediatric Well-Baby & Immunization Exam', 'fee': 600.0},
      {'name': 'Nebulization Therapy Session', 'fee': 250.0},
      {'name': 'Minor Wound Dressing & Antiseptic Care', 'fee': 350.0},
      {'name': 'Diagnostic Blood Pressure & Vitals Check', 'fee': 150.0},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Clinical Service / Consultation Fee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Standard Clinical Services:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...standardServices.map((srv) {
                final name = srv['name'] as String;
                final fee = srv['fee'] as double;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _isProcessing = true);
                      await ref.read(openInvoicesProvider.notifier).addServiceItem(
                            invoiceId: widget.invoiceId,
                            serviceName: name,
                            fee: fee,
                          );
                      if (mounted) {
                        setState(() => _isProcessing = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added $name (₱$fee) to invoice!'), backgroundColor: AppColors.success),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      alignment: Alignment.centerLeft,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                        Text('₱${fee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ],
                    ),
                  ),
                );
              }),
              const Divider(height: 24),
              const Text('Custom Procedure or Fee:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: customNameCtrl,
                decoration: const InputDecoration(labelText: 'Procedure / Service Name', hintText: 'e.g. Ear Lavage / Suturing'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: customFeeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fee Amount (₱)', prefixText: '₱ '),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = customNameCtrl.text.trim();
              final fee = double.tryParse(customFeeCtrl.text.trim()) ?? 0.0;
              if (name.isNotEmpty && fee > 0) {
                Navigator.pop(ctx);
                setState(() => _isProcessing = true);
                await ref.read(openInvoicesProvider.notifier).addServiceItem(
                      invoiceId: widget.invoiceId,
                      serviceName: name,
                      fee: fee,
                    );
                if (mounted) {
                  setState(() => _isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added $name (₱$fee) to invoice!'), backgroundColor: AppColors.success),
                  );
                }
              }
            },
            child: const Text('Add Fee'),
          ),
        ],
      ),
    );
  }

  void _showAddCatalogItemDialog() async {
    List<InventoryItem> inventoryItems = ref.read(inventoryListProvider).value ?? [];
    if (inventoryItems.isEmpty) {
      final repo = ref.read(inventoryRepositoryProvider);
      inventoryItems = await repo.getInventoryItems();
    }

    final dispensableItems = inventoryItems
        .where((i) => i.barcode != null && i.barcode!.trim().isNotEmpty && i.category.toLowerCase() != 'services')
        .toList();

    if (!mounted) return;

    if (dispensableItems.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Dispensable Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: const Text(
            'There are currently no catalog items with barcodes in the clinic formulary available to dispense.\n\nPlease add items or receive stock in the Inventory tab first.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    String selectedBarcode = dispensableItems.first.barcode!;
    int qty = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final selectedItem = dispensableItems.where((i) => i.barcode == selectedBarcode).firstOrNull ?? dispensableItems.first;
          if (selectedBarcode != selectedItem.barcode) {
            selectedBarcode = selectedItem.barcode ?? selectedBarcode;
          }

          return AlertDialog(
            title: const Text('Dispense from Clinic Catalog', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select Item to Dispense (FIFO Batch Deduction):', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBarcode,
                    isExpanded: true,
                    items: dispensableItems
                        .map((i) => DropdownMenuItem(
                              value: i.barcode!,
                              child: Text(
                                '${i.name} (₱${i.unitCost.toStringAsFixed(0)})',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedBarcode = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quantity to Dispense:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty > 1 ? () => setModalState(() => qty--) : null,
                          ),
                          Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setModalState(() => qty++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Calculated Line Total:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          '₱${(selectedItem.unitCost * qty).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(this.context);
                  Navigator.pop(ctx);
                  setState(() => _isProcessing = true);
                  final res = await ref.read(openInvoicesProvider.notifier).dispenseBarcode(
                        barcode: selectedBarcode,
                        invoiceId: widget.invoiceId,
                        quantity: qty,
                      );
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    if (res.success) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Dispensed $qty × ${res.itemName ?? selectedItem.name} into invoice!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(res.message ?? 'Dispense failed.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Dispense to Bill'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDiscountDialog(Invoice? invoice) {
    if (invoice == null) return;
    String selectedType = invoice.discountType;
    final idCtrl = TextEditingController(text: invoice.discountIdNumber ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.discount_outlined, color: AppColors.accent, size: 20),
                SizedBox(width: 8),
                Text('Statutory Discounts (PH)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Philippine RA 9994 / RA 10754 mandates 20% discount + 12% VAT Exemption on medical services & prescriptions:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    {
                      'type': 'none',
                      'title': 'None (Regular Patient)',
                      'subtitle': 'Standard gross pricing applies',
                      'color': AppColors.textPrimary,
                    },
                    {
                      'type': 'senior',
                      'title': 'Senior Citizen (RA 9994)',
                      'subtitle': '20% Statutory Discount + 12% VAT Exemption',
                      'color': AppColors.primaryDark,
                    },
                    {
                      'type': 'pwd',
                      'title': 'Person with Disability / PWD (RA 10754)',
                      'subtitle': '20% Statutory Discount + 12% VAT Exemption',
                      'color': AppColors.primaryDark,
                    },
                  ].map((opt) {
                    final type = opt['type'] as String;
                    final isSelected = selectedType == type;
                    return InkWell(
                      onTap: () => setModalState(() => selectedType = type),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryLight : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? AppColors.primary : AppColors.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(opt['title'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: opt['color'] as Color)),
                                  const SizedBox(height: 2),
                                  Text(opt['subtitle'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (selectedType == 'senior' || selectedType == 'pwd') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: idCtrl,
                      decoration: InputDecoration(
                        labelText: selectedType == 'senior' ? 'OSCA Senior ID Number' : 'PWD ID Number',
                        hintText: 'e.g. SC-12345 / PWD-9876',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  setState(() => _isProcessing = true);
                  await ref.read(openInvoicesProvider.notifier).applyDiscount(
                        invoiceId: widget.invoiceId,
                        discountType: selectedType,
                        discountIdNumber: idCtrl.text.trim().isNotEmpty ? idCtrl.text.trim() : null,
                      );
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(selectedType == 'none'
                            ? 'Removed discount from bill.'
                            : 'Applied 20% ${selectedType.toUpperCase()} discount + VAT exemption!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: const Text('Apply to Bill'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPaymentCollectionDialog(Invoice? invoice) {
    if (invoice == null) return;
    final dueAmount = invoice.netPayable;
    String selectedMethod = 'Cash';
    final tenderedCtrl = TextEditingController(text: dueAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final tendered = double.tryParse(tenderedCtrl.text.trim()) ?? dueAmount;
          final change = tendered >= dueAmount ? tendered - dueAmount : 0.0;

          return AlertDialog(
            title: const Text('Collect Encounter Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          invoice.hasSeniorOrPwdDiscount
                              ? 'Net Amount to Collect (${invoice.discountType.toUpperCase()} 20% OFF)'
                              : 'Total Amount to Collect',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${dueAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                        ),
                        if (invoice.hasSeniorOrPwdDiscount) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Gross ₱${invoice.grossAmount.toStringAsFixed(2)} · Saved ₱${(invoice.grossAmount - invoice.netPayable).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Payment Method:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: ['Cash', 'GCash', 'Card'].map((method) {
                      final isSelected = selectedMethod == method;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text(method, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            onSelected: (_) => setModalState(() => selectedMethod = method),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (selectedMethod == 'Cash') ...[
                    // Quick Cash Chips for Non-Tech Staff
                    const Text('Quick Cash Presets:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        ActionChip(
                          label: Text('Exact (₱${dueAmount.toStringAsFixed(0)})', style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            tenderedCtrl.text = dueAmount.toStringAsFixed(0);
                            setModalState(() {});
                          },
                        ),
                        if (dueAmount <= 500)
                          ActionChip(
                            label: const Text('₱500', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              tenderedCtrl.text = '500';
                              setModalState(() {});
                            },
                          ),
                        if (dueAmount <= 1000)
                          ActionChip(
                            label: const Text('₱1,000', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              tenderedCtrl.text = '1000';
                              setModalState(() {});
                            },
                          ),
                        ActionChip(
                          label: const Text('₱2,000', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            tenderedCtrl.text = '2000';
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tenderedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cash Amount Tendered (₱)', prefixText: '₱ '),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Change Due:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            '₱${change.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(this.context);
                  Navigator.pop(ctx);
                  setState(() => _isProcessing = true);
                  final success = await ref
                      .read(openInvoicesProvider.notifier)
                      .markInvoicePaid(widget.invoiceId);
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    if (success) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Payment settled via $selectedMethod! Marked as Paid.'),
                          backgroundColor: AppColors.success,
                          action: SnackBarAction(
                            label: 'Print Receipt',
                            textColor: Colors.white,
                            onPressed: () => _showPrintDialog(invoice),
                          ),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: const Text('Confirm Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPrintDialog(Invoice? invoice) {
    if (invoice == null) return;
    final clinic = ref.read(currentClinicProvider);
    final staff = ref.read(currentStaffProfileProvider);

    showDialog(
      context: context,
      builder: (ctx) => ReceiptPreviewDialog(
        invoice: invoice,
        clinic: clinic,
        cashierName: staff?.fullName ?? 'Clinical Staff',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(widget.invoiceId));
    final invoice = invoiceAsync.value;

    final isPaid = invoice?.isPaid ?? false;
    final patientName = invoice?.patientName ?? 'Juan Dela Cruz';
    final items = invoice?.lineItems ?? [];
    final totalAmount = invoice?.totalAmount ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Invoice #${widget.invoiceId}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Print Thermal Receipt',
            icon: const Icon(Icons.print, color: AppColors.primary),
            onPressed: () => _showPrintDialog(invoice),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: isPaid ? StatusBadge.paid() : StatusBadge.open(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              patientName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPaid ? 'Settled' : 'Unpaid',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Invoice ID: ${widget.invoiceId}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Dispensed items heading
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dispensed Items & Services',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${items.length} items',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 36),
                          SizedBox(height: 8),
                          Text(
                            'No items dispensed on this bill yet.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  else
                    ...items.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Qty: ${item.quantity} @ ₱${item.unitCost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₱${item.lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Senior Citizen / PWD 20% Statutory Discount Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: invoice?.hasSeniorOrPwdDiscount == true
                          ? AppColors.success.withValues(alpha: 0.08)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: invoice?.hasSeniorOrPwdDiscount == true
                            ? AppColors.success.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  invoice?.hasSeniorOrPwdDiscount == true
                                      ? Icons.verified
                                      : Icons.discount_outlined,
                                  color: invoice?.hasSeniorOrPwdDiscount == true
                                      ? AppColors.success
                                      : AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  invoice?.hasSeniorOrPwdDiscount == true
                                      ? 'PH Statutory 20% Discount (${invoice!.discountType.toUpperCase()})'
                                      : 'Senior Citizen / PWD Exemption',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (!isPaid)
                              TextButton(
                                onPressed: () => _showDiscountDialog(invoice),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  invoice?.hasSeniorOrPwdDiscount == true ? 'Change' : 'Apply 20% OFF',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: invoice?.hasSeniorOrPwdDiscount == true
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (invoice?.hasSeniorOrPwdDiscount == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            'ID: ${invoice?.discountIdNumber ?? 'Verified at Counter'} · 12% VAT Exempt + 20% Off',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Saved: ₱${(invoice!.grossAmount - invoice.netPayable).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ] else ...[
                          const SizedBox(height: 2),
                          const Text(
                            'Tap to apply 20% discount and 12% VAT exemption mandated by RA 9994 / RA 10754.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!isPaid) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showAddServiceDialog,
                            icon: const Icon(Icons.medical_services_outlined, size: 16, color: AppColors.primary),
                            label: const Text('Add Service Fee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showAddCatalogItemDialog,
                            icon: const Icon(Icons.add_shopping_cart, size: 16, color: AppColors.accent),
                            label: const Text('Dispense Med/Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.accent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: widget.onScanMore,
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                      label: const Text(
                        'Scan Barcode (Point of Care)',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Total & Checkout Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (invoice?.hasSeniorOrPwdDiscount == true) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gross Amount',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          '₱${invoice!.grossAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${invoice.discountType.toUpperCase()} (20% + VAT Exempt)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                        ),
                        Text(
                          '-₱${(invoice.grossAmount - invoice.netPayable).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        invoice?.hasSeniorOrPwdDiscount == true ? 'Net Amount Due' : 'Total Payable',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      Text(
                        '₱${(invoice?.netPayable ?? totalAmount).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: isPaid || _isProcessing ? null : () => _showPaymentCollectionDialog(invoice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPaid ? AppColors.textMuted : AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isPaid ? 'Settled in Full' : 'Collect Payment / Settle Invoice',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
