import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/notification_provider.dart';
import '../widgets/status_badge.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _showScheduleModal(BuildContext context, WidgetRef ref) {
    final patientIdCtrl = TextEditingController(text: 'p4');
    final vaccineCtrl = TextEditingController(text: 'Hepatitis B Booster');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule Vaccine Reminder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: patientIdCtrl,
              decoration: const InputDecoration(labelText: 'Patient ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: vaccineCtrl,
              decoration: const InputDecoration(labelText: 'Vaccine / Reminder Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(notificationListProvider.notifier).scheduleVaccineReminder(
                    patientId: patientIdCtrl.text,
                    vaccineName: vaccineCtrl.text,
                    dueDate: DateTime.now().add(const Duration(days: 7)),
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reminder queued in database! Automated runner will dispatch.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationListProvider);
    final notifs = notifsAsync.value ?? [];

    final pending = notifs.where((n) => n.isPending).toList();
    final sent = notifs.where((n) => n.isSent).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Automated Patient Reminders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Schedule Reminder',
            icon: const Icon(Icons.add_alert, color: AppColors.primary),
            onPressed: () => _showScheduleModal(context, ref),
          ),
          const SizedBox(width: 8),
        ],
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
          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No pending reminders in queue.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            ...pending.map((n) => _buildItem(
                  context: context,
                  ref: ref,
                  id: n.id,
                  patient: n.patientName ?? 'Patient ${n.patientId}',
                  type: n.type.replaceAll('_', ' ').toUpperCase(),
                  time: n.scheduledFor != null
                      ? 'Scheduled for: ${n.scheduledFor.toString().substring(0, 16)}'
                      : 'Scheduled',
                  isSent: false,
                )),
          const SizedBox(height: 20),
          const Text('Sent History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (sent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No sent notifications yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            ...sent.map((n) => _buildItem(
                  context: context,
                  ref: ref,
                  id: n.id,
                  patient: n.patientName ?? 'Patient ${n.patientId}',
                  type: n.type.replaceAll('_', ' ').toUpperCase(),
                  time: n.sentAt != null
                      ? 'Sent: ${n.sentAt.toString().substring(0, 16)} via SMS/Email'
                      : 'Delivered',
                  isSent: true,
                )),
        ],
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required WidgetRef ref,
    required String id,
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
          if (!isSent)
            TextButton(
              onPressed: () {
                ref.read(notificationListProvider.notifier).sendNotification(id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dispatched reminder via Twilio SMS!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Send Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            )
          else
            StatusBadge.paid(),
        ],
      ),
    );
  }
}
