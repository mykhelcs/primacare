import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/status_badge.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Automated Patient Reminders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: const [
                Text('🤖', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Automated SMS & Email dispatcher triggers daily at 8:00 AM via Supabase cron.',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const Text('Pending Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _buildItem(
            patient: 'Elena Garcia',
            type: 'Vaccine 2nd Dose Due',
            time: 'Scheduled for tomorrow, 8:00 AM',
            isSent: false,
          ),
          _buildItem(
            patient: 'Juan Dela Cruz',
            type: 'Pending Invoice #INV-2026-0891 Reminder',
            time: 'Scheduled for in 3 days',
            isSent: false,
          ),
          const SizedBox(height: 20),
          const Text('Sent History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _buildItem(
            patient: 'Maria Santos',
            type: 'Payment Receipt & Visit Summary',
            time: 'Sent today, 9:45 AM via SMS',
            isSent: true,
          ),
          _buildItem(
            patient: 'Roberto Lim',
            type: 'Doctor Follow-up Schedule',
            time: 'Sent yesterday, 2:00 PM via Email',
            isSent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String patient,
    required String type,
    required String time,
    required bool isSent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isSent ? Icons.check_circle_outline : Icons.schedule,
            color: isSent ? AppColors.success : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(type, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          isSent ? StatusBadge.paid() : StatusBadge.warning(text: 'Pending'),
        ],
      ),
    );
  }
}
