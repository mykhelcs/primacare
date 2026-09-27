import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/notification_item.dart';
import '../services/supabase_service.dart';

class NotificationRepository {
  final SupabaseClient? _client;

  NotificationRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  Future<List<NotificationItem>> getNotificationQueue() async {
    if (_client == null) {
      return _mockNotifications;
    }

    try {
      final response = await _client
          .from('notifications_queue')
          .select('*, patients(full_name)')
          .order('scheduled_for', ascending: false);

      return (response as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        if (map['patients'] != null && map['patients'] is Map) {
          map['patient_name'] = map['patients']['full_name'];
        }
        return NotificationItem.fromJson(map);
      }).toList();
    } catch (_) {
      return _mockNotifications;
    }
  }

  Future<String?> scheduleVaccineReminder({
    required String patientId,
    required String vaccineName,
    required DateTime dueDate,
  }) async {
    if (_client == null) {
      final newNotif = NotificationItem(
        id: 'n_${DateTime.now().millisecondsSinceEpoch}',
        patientId: patientId,
        type: 'vaccine_reminder',
        message: 'Reminder for $vaccineName due on ${dueDate.toIso8601String().substring(0, 10)}',
        scheduledFor: dueDate,
        status: 'pending',
      );
      _mockNotifications.insert(0, newNotif);
      return newNotif.id;
    }

    try {
      final response = await _client.rpc('schedule_vaccine_reminder', params: {
        'p_patient_id': patientId,
        'p_vaccine_name': vaccineName,
        'p_due_date': dueDate.toIso8601String(),
      });
      return response?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<bool> sendManualNotification(String notificationId) async {
    if (_client == null) {
      final index = _mockNotifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final existing = _mockNotifications[index];
        _mockNotifications[index] = NotificationItem(
          id: existing.id,
          patientId: existing.patientId,
          patientName: existing.patientName,
          type: existing.type,
          message: existing.message,
          scheduledFor: existing.scheduledFor,
          sentAt: DateTime.now(),
          status: 'sent',
        );
      }
      return true;
    }

    try {
      await _client
          .from('notifications_queue')
          .update({
            'status': 'sent',
            'sent_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static final List<NotificationItem> _mockNotifications = [
    NotificationItem(
      id: 'n1',
      patientId: 'p4',
      patientName: 'Elena Garcia',
      type: 'vaccine_reminder',
      message: 'Reminder from PrimaCare: Upcoming Hepatitis B Booster is scheduled for Oct 15, 2026.',
      scheduledFor: DateTime.now().add(const Duration(days: 1)),
      status: 'pending',
    ),
    NotificationItem(
      id: 'n2',
      patientId: 'p1',
      patientName: 'Juan Dela Cruz',
      type: 'bill_reminder',
      message: 'PrimaCare Statement: Invoice #INV-2026-0891 with balance of ₱2,400 is awaiting settlement.',
      scheduledFor: DateTime.now().add(const Duration(days: 3)),
      status: 'pending',
    ),
    NotificationItem(
      id: 'n3',
      patientId: 'p2',
      patientName: 'Maria Santos',
      type: 'follow_up',
      message: 'Payment receipt & visit care instructions have been processed.',
      sentAt: DateTime.now().subtract(const Duration(hours: 4)),
      status: 'sent',
    ),
  ];
}
