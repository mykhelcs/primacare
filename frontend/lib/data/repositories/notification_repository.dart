import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/notification_item.dart';
import '../services/supabase_service.dart';

class NotificationRepository {
  final SupabaseClient? _client;

  static final List<NotificationItem> _localNotifications = [];

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  NotificationRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseService.isInitialized ? SupabaseService.client : null);

  Future<List<NotificationItem>> getNotificationQueue() async {
    if (_client == null) {
      return [..._localNotifications, ..._mockNotifications];
    }

    try {
      final response = await _client
          .from('notifications_queue')
          .select('*, patients(full_name)')
          .order('scheduled_for', ascending: false);

      final remoteList = (response as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        if (map['patients'] != null && map['patients'] is Map) {
          map['patient_name'] = map['patients']['full_name'];
        }
        return NotificationItem.fromJson(map);
      }).toList();

      final remoteIds = remoteList.map((n) => n.id).toSet();
      final unmerged = _localNotifications.where((n) => !remoteIds.contains(n.id));
      return [...unmerged, ...remoteList];
    } catch (_) {
      return [..._localNotifications, ..._mockNotifications];
    }
  }

  Future<String> scheduleVaccineReminder({
    required String patientId,
    required String vaccineName,
    required DateTime dueDate,
    String? patientName,
  }) async {
    final newId = 'n_${DateTime.now().millisecondsSinceEpoch}';
    final fallbackNotif = NotificationItem(
      id: newId,
      patientId: patientId,
      patientName: patientName,
      type: 'vaccine_reminder',
      message: 'Reminder for $vaccineName due on ${dueDate.toIso8601String().substring(0, 10)}',
      scheduledFor: dueDate,
      status: 'pending',
    );

    if (_client != null && _uuidRegex.hasMatch(patientId)) {
      try {
        final response = await _client
            .from('notifications_queue')
            .insert({
              'patient_id': patientId,
              'type': 'vaccine_reminder',
              'message': fallbackNotif.message,
              'scheduled_for': dueDate.toIso8601String(),
              'status': 'pending',
            })
            .select()
            .single();
        final created = NotificationItem.fromJson(response);
        _localNotifications.insert(0, created);
        return created.id;
      } catch (_) {}
    }

    _localNotifications.insert(0, fallbackNotif);
    return newId;
  }

  Future<bool> sendManualNotification(String notificationId) async {
    // Update local cache first
    final localIdx = _localNotifications.indexWhere((n) => n.id == notificationId);
    if (localIdx != -1) {
      final existing = _localNotifications[localIdx];
      _localNotifications[localIdx] = NotificationItem(
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

    final mockIdx = _mockNotifications.indexWhere((n) => n.id == notificationId);
    if (mockIdx != -1) {
      final existing = _mockNotifications[mockIdx];
      _mockNotifications[mockIdx] = NotificationItem(
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

    if (_client != null && _uuidRegex.hasMatch(notificationId)) {
      try {
        await _client
            .from('notifications_queue')
            .update({
              'status': 'sent',
              'sent_at': DateTime.now().toIso8601String(),
            })
            .eq('id', notificationId);
        return true;
      } catch (_) {}
    }

    return true;
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
