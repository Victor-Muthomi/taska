import 'package:flutter/material.dart';

import '../../features/tasks/domain/entities/task.dart';
import '../notifications/notification_channels.dart';
import '../scheduling/slot_schedule.dart';

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.defaultSnoozeMinutes,
    required this.preferredReminderIntensity,
    required this.preferredNotificationPriority,
    required this.allowPriorityEscalation,
    required this.slotWindows,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      themeMode: ThemeMode.light,
      defaultSnoozeMinutes: 10,
      preferredReminderIntensity: TaskReminderIntensity.normal,
      preferredNotificationPriority: ReminderPriority.normal,
      allowPriorityEscalation: true,
      slotWindows: SlotSchedule.defaultWindows,
    );
  }

  final ThemeMode themeMode;
  final int defaultSnoozeMinutes;
  final TaskReminderIntensity preferredReminderIntensity;
  final ReminderPriority preferredNotificationPriority;
  final bool allowPriorityEscalation;
  final Map<TaskSlot, SlotWindow> slotWindows;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? defaultSnoozeMinutes,
    TaskReminderIntensity? preferredReminderIntensity,
    ReminderPriority? preferredNotificationPriority,
    bool? allowPriorityEscalation,
    Map<TaskSlot, SlotWindow>? slotWindows,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      preferredReminderIntensity:
          preferredReminderIntensity ?? this.preferredReminderIntensity,
      preferredNotificationPriority:
          preferredNotificationPriority ?? this.preferredNotificationPriority,
      allowPriorityEscalation:
          allowPriorityEscalation ?? this.allowPriorityEscalation,
      slotWindows: slotWindows ?? this.slotWindows,
    );
  }
}
