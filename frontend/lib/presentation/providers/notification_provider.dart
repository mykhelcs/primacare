import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/notification_item.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationListProvider =
    AsyncNotifierProvider<NotificationListNotifier, List<NotificationItem>>(
  NotificationListNotifier.new,
);

class NotificationListNotifier extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    final repo = ref.read(notificationRepositoryProvider);
    return repo.getNotificationQueue();
  }

  Future<void> sendNotification(String id) async {
    final current = state.value ?? [];
    state = AsyncData(current.map((n) {
      if (n.id == id) {
        return NotificationItem(
          id: n.id,
          patientId: n.patientId,
          patientName: n.patientName,
          type: n.type,
          message: n.message,
          scheduledFor: n.scheduledFor,
          sentAt: DateTime.now(),
          status: 'sent',
        );
      }
      return n;
    }).toList());

    final repo = ref.read(notificationRepositoryProvider);
    await repo.sendManualNotification(id);
    final refreshed = await repo.getNotificationQueue();
    state = AsyncData(refreshed);
  }

  Future<void> scheduleVaccineReminder({
    required String patientId,
    required String vaccineName,
    required DateTime dueDate,
    String? patientName,
  }) async {
    final repo = ref.read(notificationRepositoryProvider);
    final id = await repo.scheduleVaccineReminder(
      patientId: patientId,
      vaccineName: vaccineName,
      dueDate: dueDate,
      patientName: patientName,
    );

    final newNotif = NotificationItem(
      id: id,
      patientId: patientId,
      patientName: patientName,
      type: 'vaccine_reminder',
      message: 'Reminder for $vaccineName due on ${dueDate.toIso8601String().substring(0, 10)}',
      scheduledFor: dueDate,
      status: 'pending',
    );

    final current = state.value ?? [];
    state = AsyncData([newNotif, ...current.where((n) => n.id != id)]);

    final refreshed = await repo.getNotificationQueue();
    state = AsyncData(refreshed);
  }
}
