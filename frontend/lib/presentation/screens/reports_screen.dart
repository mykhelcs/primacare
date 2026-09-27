import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/stat_card.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
