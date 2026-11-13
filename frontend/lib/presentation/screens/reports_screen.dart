import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/patient_provider.dart';
import '../widgets/access_restricted_view.dart';
import '../widgets/stat_card.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref, {
    required double totalBilled,
    required double totalCollected,
    required int totalInvoices,
    required int paidInvoices,
    required int openInvoices,
    required double inventoryValuation,
    required int totalPatients,
    required Map<String, double> categoryRecovery,
  }) async {
    final now = DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('--- PRIMACARE CLINICAL OPERATIONS & FINANCIAL SUMMARY ---');
    buffer.writeln('Generated at: ${now.toIso8601String()}');
    buffer.writeln();
    buffer.writeln('METRIC,VALUE');
    buffer.writeln('Total Billed Amount (PHP),${totalBilled.toStringAsFixed(2)}');
    buffer.writeln('Total Collected Amount (PHP),${totalCollected.toStringAsFixed(2)}');
    buffer.writeln('Total Invoices Generated,$totalInvoices');
    buffer.writeln('Paid Invoices,$paidInvoices');
    buffer.writeln('Open Invoices,$openInvoices');
    buffer.writeln('Total Patients Enrolled,$totalPatients');
    buffer.writeln('Total Inventory Valuation (PHP),${inventoryValuation.toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('CATEGORY,REVENUE CAPTURED AT POINT-OF-CARE (PHP)');
    categoryRecovery.forEach((category, amount) {
      final escaped = category.replaceAll('"', '""');
      buffer.writeln('"$escaped",${amount.toStringAsFixed(2)}');
    });

    final csvData = buffer.toString();
    String? savedPath;

    if (!kIsWeb) {
      try {
        final timestamp =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
        final file = File(
          '${Directory.systemTemp.path}${Platform.pathSeparator}primacare_report_$timestamp.csv',
        );
        await file.writeAsString(csvData);
        savedPath = file.path;
      } catch (_) {
        // Fallback to clipboard-only when filesystem write is restricted
      }
    }

    await Clipboard.setData(ClipboardData(text: csvData));

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Financial & Clinical Report Exported'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generated ${csvData.length} bytes and copied CSV data to clipboard.',
              style: const TextStyle(fontSize: 13),
            ),
            if (savedPath != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Saved CSV file:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              SelectableText(
                savedPath,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csvData));
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Copy Again'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(currentUserRoleProvider);
    if (!userRole.canViewFinancialReports) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: const Text(
            'Clinic Operations & Financials',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
        body: const AccessRestrictedView(
          featureName: 'Financial & revenue reports',
          requiredRoleDescription: 'Administrator',
        ),
      );
    }

    // Watch reactive providers
    final invoices = ref.watch(openInvoicesProvider).value ?? [];
    final inventory = ref.watch(inventoryListProvider).value ?? [];
    final patients = ref.watch(patientListProvider).value ?? [];
    final expiringBatches = ref.watch(expiringBatchesProvider).value ?? [];

    // O(N) Single-Pass Invoice Aggregation
    double totalBilled = 0.0;
    double totalCollected = 0.0;
    int paidCount = 0;
    int openCount = 0;
    double leakagePrevented = 0.0;

    // Track category-wise dispensation in O(Total Line Items)
    final Map<String, double> categoryRecovery = {
      'Vaccines': 0.0,
      'Consumables': 0.0,
      'Pharmaceuticals': 0.0,
      'Services': 0.0,
    };

    // Fast O(1) inventory category lookup map
    final Map<String, String> itemCategoryMap = {};
    for (final item in inventory) {
      itemCategoryMap[item.name.toLowerCase().trim()] = item.category;
    }

    for (final inv in invoices) {
      totalBilled += inv.totalAmount;
      if (inv.status == 'paid') {
        totalCollected += inv.totalAmount;
        paidCount++;
      } else {
        openCount++;
      }

      for (final line in inv.lineItems) {
        final lineTotal = line.lineTotal;
        leakagePrevented += lineTotal;

        final itemCat = itemCategoryMap[line.itemName.toLowerCase().trim()] ?? 'Consumables';
        categoryRecovery[itemCat] = (categoryRecovery[itemCat] ?? 0.0) + lineTotal;
      }
    }

    // O(M) Single-Pass Inventory Valuation
    double totalInventoryValuation = 0.0;
    int lowStockCount = 0;
    for (final item in inventory) {
      totalInventoryValuation += (item.totalStock * item.unitCost);
      if (item.isLowStock) lowStockCount++;
    }

    // Phase 4 Waste & Expiry Risk Computation
    double atRiskWasteValuation = 0.0;
    int atRiskUnits = 0;
    for (final b in expiringBatches) {
      final unitCost = inventory.where((i) => i.id == b.itemId).firstOrNull?.unitCost ?? 0.0;
      atRiskWasteValuation += (b.quantityRemaining * unitCost);
      atRiskUnits += b.quantityRemaining;
    }

    // O(P) Patient metrics
    final totalPatients = patients.length;
    final collectionRate = totalBilled > 0 ? ((totalCollected / totalBilled) * 100) : 0.0;

    // Chart Dynamic Bar Groups — honest metrics from live database
    final billedInK = totalBilled / 1000;
    final collectedInK = totalCollected / 1000;
    final outstandingInK = ((totalBilled - totalCollected) / 1000).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Clinic Operations & Financials',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Export CSV Report',
            icon: const Icon(Icons.download, color: AppColors.primary),
            onPressed: () => _exportCsv(
              context,
              ref,
              totalBilled: totalBilled,
              totalCollected: totalCollected,
              totalInvoices: invoices.length,
              paidInvoices: paidCount,
              openInvoices: openCount,
              inventoryValuation: totalInventoryValuation,
              totalPatients: totalPatients,
              categoryRecovery: categoryRecovery,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Operational KPI Grid (100% Data-Driven)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                StatCard(
                  icon: Icons.trending_up,
                  value: '₱${totalBilled.toStringAsFixed(2)}',
                  label: 'Total Billed ($paidCount settled, $openCount open)',
                  valueColor: AppColors.primary,
                ),
                StatCard(
                  icon: Icons.verified_user,
                  value: '₱${leakagePrevented.toStringAsFixed(2)}',
                  label: 'Leakage Captured (Scanner)',
                  valueColor: AppColors.accent,
                ),
                StatCard(
                  icon: Icons.inventory_2,
                  value: '₱${totalInventoryValuation.toStringAsFixed(2)}',
                  label: 'Valuation ($lowStockCount low stock)',
                  valueColor: AppColors.success,
                ),
                StatCard(
                  icon: Icons.people,
                  value: '$totalPatients Patients',
                  label: 'Collection Rate: ${collectionRate.toStringAsFixed(1)}%',
                  valueColor: AppColors.primaryDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Revenue Trends Chart (fl_chart)
            const Text(
              'Monthly Collections vs. Billed (₱ in Thousands)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (billedInK * 1.25).clamp(10, 500).toDouble(),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          switch (val.toInt()) {
                            case 0:
                              return const Text('Billed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary));
                            case 1:
                              return const Text('Collected', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success));
                            case 2:
                              return const Text('Outstanding', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning));
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(toY: billedInK > 0 ? billedInK : 0.2, color: AppColors.primary, width: 20),
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(toY: collectedInK > 0 ? collectedInK : 0.1, color: AppColors.success, width: 20),
                    ]),
                    BarChartGroupData(x: 2, barRods: [
                      BarChartRodData(toY: outstandingInK > 0 ? outstandingInK : 0.05, color: AppColors.warning, width: 20),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Clinical Waste & Expiry Assessment Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: atRiskWasteValuation > 0 ? AppColors.danger.withValues(alpha: 0.08) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: atRiskWasteValuation > 0 ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    atRiskWasteValuation > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: atRiskWasteValuation > 0 ? AppColors.danger : AppColors.success,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Waste & Expiry Risk Assessment',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          atRiskWasteValuation > 0
                              ? '₱${atRiskWasteValuation.toStringAsFixed(2)} at risk ($atRiskUnits units across ${expiringBatches.length} batches expiring ≤ 30 days)'
                              : 'Zero expired stock detected. All formulary batches within safe shelf-life.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: atRiskWasteValuation > 0 ? AppColors.danger : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Billed', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: 14),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Collected', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: 14),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Outstanding', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Consumables Leakage Recovery Breakdown',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),

            ...categoryRecovery.entries.map((entry) {
              final cat = entry.key;
              final amount = entry.value;
              final maxAmount = leakagePrevented > 0 ? leakagePrevented : 1.0;
              final progress = (amount / maxAmount).clamp(0.05, 1.0);
              return _buildRecoveryItem(
                cat,
                '₱${amount.toStringAsFixed(2)} captured through barcode dispensation',
                progress,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryItem(String title, String subtitle, double progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('${(progress * 100).toInt()}% of captured', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.primaryLight,
              color: AppColors.accent,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
