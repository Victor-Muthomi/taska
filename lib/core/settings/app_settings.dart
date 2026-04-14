import 'package:flutter/material.dart';

import '../../features/tasks/domain/entities/task.dart';
import '../notifications/notification_channels.dart';
import '../scheduling/slot_schedule.dart';

enum AppCurrency { usd, eur, gbp, kes }

extension AppCurrencyX on AppCurrency {
  String get label {
    return switch (this) {
      AppCurrency.usd => 'US Dollar (USD)',
      AppCurrency.eur => 'Euro (EUR)',
      AppCurrency.gbp => 'British Pound (GBP)',
      AppCurrency.kes => 'Kenyan Shilling (KES)',
    };
  }

  String get symbol {
    return switch (this) {
      AppCurrency.usd => '\$',
      AppCurrency.eur => 'EUR ',
      AppCurrency.gbp => 'GBP ',
      AppCurrency.kes => 'KES ',
    };
  }
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.currency,
    required this.defaultSnoozeMinutes,
    required this.preferredReminderIntensity,
    required this.preferredNotificationPriority,
    required this.allowPriorityEscalation,
    required this.slotWindows,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      themeMode: ThemeMode.light,
      currency: AppCurrency.usd,
      defaultSnoozeMinutes: 10,
      preferredReminderIntensity: TaskReminderIntensity.normal,
      preferredNotificationPriority: ReminderPriority.normal,
      allowPriorityEscalation: true,
      slotWindows: SlotSchedule.defaultWindows,
    );
  }

  final ThemeMode themeMode;
  final AppCurrency currency;
  final int defaultSnoozeMinutes;
  final TaskReminderIntensity preferredReminderIntensity;
  final ReminderPriority preferredNotificationPriority;
  final bool allowPriorityEscalation;
  final Map<TaskSlot, SlotWindow> slotWindows;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppCurrency? currency,
    int? defaultSnoozeMinutes,
    TaskReminderIntensity? preferredReminderIntensity,
    ReminderPriority? preferredNotificationPriority,
    bool? allowPriorityEscalation,
    Map<TaskSlot, SlotWindow>? slotWindows,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
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
