import 'package:flutter_test/flutter_test.dart';

import 'package:taska/core/notifications/notification_channels.dart';
import 'package:taska/core/notifications/notification_logic.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';

void main() {
  group('NotificationLogic', () {
    test('maps reminder intensity to channel priority', () {
      expect(
        NotificationLogic.priorityForIntensity(TaskReminderIntensity.low),
        ReminderPriority.low,
      );
      expect(
        NotificationLogic.priorityForIntensity(TaskReminderIntensity.normal),
        ReminderPriority.normal,
      );
      expect(
        NotificationLogic.priorityForIntensity(TaskReminderIntensity.high),
        ReminderPriority.high,
      );
    });

    test('maps default tap to opened event', () {
      expect(
        NotificationLogic.eventTypeForActionId(null),
        NotificationEventType.opened,
      );
      expect(
        NotificationLogic.eventTypeForActionId(''),
        NotificationEventType.opened,
      );
    });

    test('maps snooze action to snoozed event', () {
      expect(
        NotificationLogic.eventTypeForActionId(snoozeNotificationActionId),
        NotificationEventType.snoozed,
      );
    });
  });
}
