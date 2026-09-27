import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/report_provider.dart';
import '../widgets/stat_card.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  void _exportCsv(BuildContext context, WidgetRef ref) {
    final repo = ref.read(reportRepositoryProvider);
    final summaries = ref.read(monthlyBillingProvider).value ?? [];
    final leakages = ref.read(leakageRecoveryProvider).value ?? [];

    final csvData = repo.exportReportsAsCsv(
      billingSummaries: summaries,
      leakageReports: leakages,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${csvData.length} bytes to CSV successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download, color: AppColors.primary),
            onPressed: () => _exportCsv(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: const [
                StatCard(
                  icon: '📈',
                  value: '₱148.2k',
                  label: 'Total Billed (Month)',
                  valueColor: AppColors.primary,
                ),
                StatCard(
                  icon: '🛡️',
                  value: '₱18.4k',
                  label: 'Leakage Prevented',
                  valueColor: AppColors.accent,
                ),
                StatCard(
                  icon: '📦',
                  value: '₱0',
                  label: 'Expired Waste (FIFO)',
                  valueColor: AppColors.success,
                ),
                StatCard(
                  icon: '🔁',
                  value: '88%',
                  label: 'Patient Return Rate',
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
              height: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 160,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          switch (val.toInt()) {
                            case 0:
                              return const Text('July', style: TextStyle(fontSize: 10));
                            case 1:
                              return const Text('August', style: TextStyle(fontSize: 10));
                            case 2:
                              return const Text('September', style: TextStyle(fontSize: 10));
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
                      BarChartRodData(toY: 95, color: AppColors.primary, width: 14),
                      BarChartRodData(toY: 88, color: AppColors.accent, width: 14),
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(toY: 112, color: AppColors.primary, width: 14),
                      BarChartRodData(toY: 104, color: AppColors.accent, width: 14),
                    ]),
                    BarChartGroupData(x: 2, barRods: [
                      BarChartRodData(toY: 148, color: AppColors.primary, width: 14),
                      BarChartRodData(toY: 130, color: AppColors.accent, width: 14),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Consumables Leakage Recovery Breakdown',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            _buildRecoveryItem('Hepatitis B & Infant Vaccines', '₱9,450 captured at point-of-care', 0.85),
            _buildRecoveryItem('Syringes, Needles & Gauze', '₱5,200 previously unbilled consumables', 0.65),
            _buildRecoveryItem('Emergency Antibiotics & Vials', '₱3,800 accounted through scanner', 0.45),
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
              Text('${(progress * 100).toInt()}% captured', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
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
