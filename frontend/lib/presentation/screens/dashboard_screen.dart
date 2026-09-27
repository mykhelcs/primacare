import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onScanTapped;
  final ValueChanged<String>? onInvoiceTapped;

  const DashboardScreen({
    super.key,
    this.onScanTapped,
    this.onInvoiceTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Good morning, Nurse Ana 👋',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'PrimaCare Clinic · Today',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Text('🔔', style: TextStyle(fontSize: 18)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat Cards Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: const [
                StatCard(
                  icon: '🧾',
                  value: '12',
                  label: 'Open invoices',
                  valueColor: AppColors.primary,
                ),
                StatCard(
                  icon: '👥',
                  value: '7',
                  label: 'Patients today',
                  valueColor: AppColors.accent,
                ),
                StatCard(
                  icon: '⚠️',
                  value: '5',
                  label: 'Expiry alerts',
                  valueColor: AppColors.warning,
                ),
                StatCard(
                  icon: '💰',
                  value: '₱38k',
                  label: 'Billed today',
                  valueColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick action button
            ElevatedButton(
              onPressed: onScanTapped,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('📷', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Scan Item to Bill',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recent Invoices section
            const Text(
              'Recent Invoices',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            _buildInvoiceTile(
              initials: 'JD',
              avatarColor: AppColors.primary,
              patientName: 'Juan Dela Cruz',
              itemCount: 3,
              isOpen: true,
              amount: '₱2,400',
              time: '10:15 AM',
              onTap: () => onInvoiceTapped?.call('inv-1'),
            ),
            _buildInvoiceTile(
              initials: 'MS',
              avatarColor: AppColors.success,
              patientName: 'Maria Santos',
              itemCount: 1,
              isOpen: false,
              amount: '₱850',
              time: '09:40 AM',
              onTap: () => onInvoiceTapped?.call('inv-2'),
            ),
            _buildInvoiceTile(
              initials: 'RL',
              avatarColor: AppColors.primaryDark,
              patientName: 'Roberto Lim',
              itemCount: 4,
              isOpen: true,
              amount: '₱3,100',
              time: '09:12 AM',
              onTap: () => onInvoiceTapped?.call('inv-3'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceTile({
    required String initials,
    required Color avatarColor,
    required String patientName,
    required int itemCount,
    required bool isOpen,
    required String amount,
    required String time,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: avatarColor.withValues(alpha: 0.15),
          child: Text(
            initials,
            style: TextStyle(
              color: avatarColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        title: Text(
          patientName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Row(
          children: [
            isOpen ? StatusBadge.open() : StatusBadge.paid(),
            const SizedBox(width: 8),
            Text(
              '$itemCount items',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
