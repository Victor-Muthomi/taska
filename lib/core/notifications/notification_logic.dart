import '../../features/tasks/domain/entities/task.dart';
import 'notification_channels.dart';

enum NotificationEventType { opened, snoozed }

const snoozeNotificationActionId = 'snooze_action';

class NotificationLogic {
  const NotificationLogic._();

  static ReminderPriority priorityForIntensity(
    TaskReminderIntensity intensity,
  ) {
    return switch (intensity) {
      TaskReminderIntensity.low => ReminderPriority.low,
      TaskReminderIntensity.normal => ReminderPriority.normal,
      TaskReminderIntensity.high => ReminderPriority.high,
    };
  }

  static ReminderPriority resolvePriority({
    required TaskReminderIntensity intensity,
    required ReminderPriority preferredPriority,
    required bool allowPriorityEscalation,
  }) {
    final adaptivePriority = priorityForIntensity(intensity);
    if (!allowPriorityEscalation) {
      return preferredPriority;
    }

    return adaptivePriority.level > preferredPriority.level
        ? adaptivePriority
        : preferredPriority;
  }

  static NotificationEventType eventTypeForActionId(String? actionId) {
    if (actionId == snoozeNotificationActionId) {
      return NotificationEventType.snoozed;
    }
    return NotificationEventType.opened;
  }
}
