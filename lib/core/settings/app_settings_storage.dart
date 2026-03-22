import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/tasks/domain/entities/task.dart';
import '../notifications/notification_channels.dart';
import '../scheduling/slot_schedule.dart';
import 'app_settings.dart';

class AppSettingsStorage {
  const AppSettingsStorage();

  static const _fileName = 'taska_settings.json';

  Future<AppSettings> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        return AppSettings.defaults();
      }

      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings(
        themeMode: _themeModeFromName(map['themeMode'] as String?),
        defaultSnoozeMinutes:
            (map['defaultSnoozeMinutes'] as num?)?.toInt() ?? 10,
        preferredReminderIntensity: _intensityFromName(
          map['preferredReminderIntensity'] as String?,
        ),
        preferredNotificationPriority: _priorityFromName(
          map['preferredNotificationPriority'] as String?,
        ),
        allowPriorityEscalation:
            map['allowPriorityEscalation'] as bool? ?? true,
        slotWindows: _slotWindowsFromJson(
          map['slotWindows'] as Map<String, dynamic>?,
        ),
      );
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _settingsFile();
    await file.writeAsString(
      jsonEncode({
        'themeMode': settings.themeMode.name,
        'defaultSnoozeMinutes': settings.defaultSnoozeMinutes,
        'preferredReminderIntensity': settings.preferredReminderIntensity.name,
        'preferredNotificationPriority':
            settings.preferredNotificationPriority.name,
        'allowPriorityEscalation': settings.allowPriorityEscalation,
        'slotWindows': {
          for (final entry in settings.slotWindows.entries)
            entry.key.name: {
              'startHour': entry.value.startHour,
              'startMinute': entry.value.startMinute,
              'endHour': entry.value.endHour,
              'endMinute': entry.value.endMinute,
            },
        },
      }),
    );
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  ThemeMode _themeModeFromName(String? value) {
    return switch (value) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  TaskReminderIntensity _intensityFromName(String? value) {
    return switch (value) {
      'low' => TaskReminderIntensity.low,
      'high' => TaskReminderIntensity.high,
      _ => TaskReminderIntensity.normal,
    };
  }

  ReminderPriority _priorityFromName(String? value) {
    return switch (value) {
      'low' => ReminderPriority.low,
      'high' => ReminderPriority.high,
      _ => ReminderPriority.normal,
    };
  }

  Map<TaskSlot, SlotWindow> _slotWindowsFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return SlotSchedule.defaultWindows;
    }

    final windows = <TaskSlot, SlotWindow>{};
    for (final slot in TaskSlot.values) {
      final rawWindow = json[slot.name];
      final defaultWindow = SlotSchedule.defaultWindows[slot]!;
      if (rawWindow is! Map<String, dynamic>) {
        windows[slot] = defaultWindow;
        continue;
      }

      windows[slot] = SlotWindow(
        startHour: (rawWindow['startHour'] as num?)?.toInt() ??
            defaultWindow.startHour,
        startMinute: (rawWindow['startMinute'] as num?)?.toInt() ??
            defaultWindow.startMinute,
        endHour: (rawWindow['endHour'] as num?)?.toInt() ??
            defaultWindow.endHour,
        endMinute: (rawWindow['endMinute'] as num?)?.toInt() ??
            defaultWindow.endMinute,
      );
    }

    return windows;
  }
}
