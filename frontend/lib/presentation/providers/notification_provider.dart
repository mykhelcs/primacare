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
    final repo = ref.read(notificationRepositoryProvider);
    final success = await repo.sendManualNotification(id);
    if (success) {
      state = AsyncData(await repo.getNotificationQueue());
    }
  }

  Future<void> scheduleVaccineReminder({
    required String patientId,
    required String vaccineName,
    required DateTime dueDate,
  }) async {
    final repo = ref.read(notificationRepositoryProvider);
    await repo.scheduleVaccineReminder(
      patientId: patientId,
      vaccineName: vaccineName,
      dueDate: dueDate,
    );
    state = AsyncData(await repo.getNotificationQueue());
  }
}
