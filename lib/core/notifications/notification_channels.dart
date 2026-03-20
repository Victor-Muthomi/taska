import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum ReminderPriority { low, normal, high }

extension ReminderPriorityX on ReminderPriority {
  int get level => switch (this) {
    ReminderPriority.low => 0,
    ReminderPriority.normal => 1,
    ReminderPriority.high => 2,
  };

  String get label => switch (this) {
    ReminderPriority.low => 'Gentle',
    ReminderPriority.normal => 'Balanced',
    ReminderPriority.high => 'Urgent',
  };

  String get channelId => switch (this) {
    ReminderPriority.low => 'taska_low_priority',
    ReminderPriority.normal => 'taska_normal_priority',
    ReminderPriority.high => 'taska_high_priority',
  };

  String get channelName => switch (this) {
    ReminderPriority.low => 'Gentle Reminders',
    ReminderPriority.normal => 'Smart Reminders',
    ReminderPriority.high => 'Urgent Reminders',
  };

  String get channelDescription => switch (this) {
    ReminderPriority.low => 'Low intensity reminders for flexible tasks.',
    ReminderPriority.normal => 'Default reminders for scheduled tasks.',
    ReminderPriority.high =>
      'High priority reminders for tasks that need attention.',
  };

  Importance get importance => switch (this) {
    ReminderPriority.low => Importance.defaultImportance,
    ReminderPriority.normal => Importance.high,
    ReminderPriority.high => Importance.max,
  };

  Priority get priority => switch (this) {
    ReminderPriority.low => Priority.defaultPriority,
    ReminderPriority.normal => Priority.high,
    ReminderPriority.high => Priority.max,
  };
}
