import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/notification_item.dart';
import '../providers/notification_provider.dart';
import '../providers/patient_provider.dart';
import '../widgets/status_badge.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _showScheduleModal(BuildContext context, WidgetRef ref) {
    final patients = ref.read(patientListProvider).value ?? [];
    String selectedPatientId = patients.isNotEmpty ? patients.first.id : 'p1';
    String selectedPatientName = patients.isNotEmpty ? patients.first.fullName : 'Selected Patient';
    final vaccineCtrl = TextEditingController(text: 'Hepatitis B Booster');
    int daysAhead = 7;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text(
            'Schedule Automated Reminder',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (patients.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedPatientId,
                    decoration: const InputDecoration(labelText: 'Recipient Patient *'),
                    items: patients
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.fullName} (${p.contactNumber ?? 'No Phone'})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedPatientId = val;
                          final match = patients.where((p) => p.id == val).firstOrNull;
                          if (match != null) selectedPatientName = match.fullName;
                        });
                      }
                    },
                  )
                else
                  TextField(
                    decoration: const InputDecoration(labelText: 'Patient ID'),
                    onChanged: (val) => selectedPatientId = val.trim(),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: vaccineCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reminder Message / Purpose *',
                    hintText: 'e.g. Hepatitis B Vaccine Booster / 7-Day Follow-Up',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: daysAhead,
                  decoration: const InputDecoration(labelText: 'Schedule Dispatch In'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 Day (Tomorrow 8:00 AM)')),
                    DropdownMenuItem(value: 3, child: Text('3 Days Ahead')),
                    DropdownMenuItem(value: 7, child: Text('7 Days Ahead (1 Week)')),
                    DropdownMenuItem(value: 14, child: Text('14 Days Ahead (2 Weeks)')),
                    DropdownMenuItem(value: 30, child: Text('30 Days Ahead (1 Month)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => daysAhead = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final message = vaccineCtrl.text.trim();
                if (message.isNotEmpty) {
                  ref.read(notificationListProvider.notifier).scheduleVaccineReminder(
                        patientId: selectedPatientId,
                        patientName: selectedPatientName,
                        vaccineName: message,
                        dueDate: DateTime.now().add(Duration(days: daysAhead)),
                      );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Automated reminder queued for $selectedPatientName!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Schedule Reminder'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationListProvider);
    final notifs = notifsAsync.value ?? [];

    // O(N) Single-Pass Partitioning into Pending and Sent Lists
    final pending = <NotificationItem>[];
    final sent = <NotificationItem>[];
    for (final n in notifs) {
      if (n.isPending) {
        pending.add(n);
      } else {
        sent.add(n);
      }
    }

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
          Text(
            'Pending Reminders (${pending.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
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
          Text(
            'Sent History (${sent.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
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
                    content: Text('Dispatched reminder via Twilio SMS & SendGrid Email!'),
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
