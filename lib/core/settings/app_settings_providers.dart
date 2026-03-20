import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/tasks/domain/entities/task.dart';
import '../notifications/notification_channels.dart';
import '../scheduling/slot_schedule.dart';
import 'app_settings.dart';
import 'app_settings_storage.dart';

final appSettingsStorageProvider = Provider<AppSettingsStorage>((ref) {
  return const AppSettingsStorage();
});

final initialAppSettingsProvider = Provider<AppSettings>((ref) {
  return AppSettings.defaults();
});

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final settings = ref.watch(initialAppSettingsProvider);
    SlotSchedule.configure(settings.slotWindows);
    return settings;
  }

  Future<void> toggleThemeMode() async {
    final nextMode = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await updateThemeMode(nextMode);
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    await _save(state.copyWith(themeMode: themeMode));
  }

  Future<void> updateDefaultSnoozeMinutes(int minutes) async {
    await _save(state.copyWith(defaultSnoozeMinutes: minutes));
  }

  Future<void> updatePreferredReminderIntensity(
    TaskReminderIntensity intensity,
  ) async {
    await _save(state.copyWith(preferredReminderIntensity: intensity));
  }

  Future<void> updateNotificationPreferences({
    ReminderPriority? preferredPriority,
    bool? allowPriorityEscalation,
  }) async {
    await _save(
      state.copyWith(
        preferredNotificationPriority:
            preferredPriority ?? state.preferredNotificationPriority,
        allowPriorityEscalation:
            allowPriorityEscalation ?? state.allowPriorityEscalation,
      ),
    );
  }

  Future<void> updateSlotWindow(TaskSlot slot, SlotWindow window) async {
    final startMinutes = window.startHour * 60 + window.startMinute;
    final endMinutes = window.endHour * 60 + window.endMinute;
    if (endMinutes <= startMinutes + 15) {
      return;
    }

    final nextWindows = <TaskSlot, SlotWindow>{
      ...state.slotWindows,
      slot: window,
    };
    await _save(state.copyWith(slotWindows: nextWindows));
  }

  Future<void> _save(AppSettings nextState) async {
    state = nextState;
    SlotSchedule.configure(nextState.slotWindows);
    await ref.read(appSettingsStorageProvider).save(nextState);
  }
}
