import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_channels.dart';
import '../../../../core/scheduling/slot_schedule.dart';
import '../../../../core/settings/app_settings_providers.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../tasks/domain/entities/task.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Tune the reminder system around your day instead of forcing your day around the app.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Card(
            child: SwitchListTile(
              value: isDark,
              title: const Text('Dark mode'),
              subtitle: const Text('Your theme choice now stays saved.'),
              secondary: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              ),
              onChanged: (_) {
                ref.read(appSettingsProvider.notifier).toggleThemeMode();
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Currency'),
              subtitle: Text(settings.currency.label),
              trailing: DropdownButton<AppCurrency>(
                value: settings.currency,
                underline: const SizedBox.shrink(),
                items: AppCurrency.values
                    .map(
                      (currency) => DropdownMenuItem(
                        value: currency,
                        child: Text(currency.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  ref.read(appSettingsProvider.notifier).updateCurrency(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Default snooze duration'),
              subtitle: Text('${settings.defaultSnoozeMinutes} minutes'),
              trailing: DropdownButton<int>(
                value: settings.defaultSnoozeMinutes,
                underline: const SizedBox.shrink(),
                items: const [5, 10, 15, 20, 30]
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes min'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  ref
                      .read(appSettingsProvider.notifier)
                      .updateDefaultSnoozeMinutes(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Reminder intensity'),
              subtitle: Text(
                _intensityLabel(settings.preferredReminderIntensity),
              ),
              trailing: DropdownButton<TaskReminderIntensity>(
                value: settings.preferredReminderIntensity,
                underline: const SizedBox.shrink(),
                items: TaskReminderIntensity.values
                    .map(
                      (intensity) => DropdownMenuItem(
                        value: intensity,
                        child: Text(_intensityLabel(intensity)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  ref
                      .read(appSettingsProvider.notifier)
                      .updatePreferredReminderIntensity(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Notification channel preference'),
                  subtitle: Text(settings.preferredNotificationPriority.label),
                  trailing: DropdownButton<ReminderPriority>(
                    value: settings.preferredNotificationPriority,
                    underline: const SizedBox.shrink(),
                    items: ReminderPriority.values
                        .map(
                          (priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(priority.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      ref
                          .read(appSettingsProvider.notifier)
                          .updateNotificationPreferences(
                            preferredPriority: value,
                          );
                    },
                  ),
                ),
                SwitchListTile(
                  value: settings.allowPriorityEscalation,
                  title: const Text('Allow smart escalation'),
                  subtitle: const Text(
                    'Ignored tasks can move into stronger reminder channels.',
                  ),
                  onChanged: (value) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .updateNotificationPreferences(
                          allowPriorityEscalation: value,
                        );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slot windows',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adjust the time windows that define your day.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final slot in TaskSlot.values) ...[
                    _SlotWindowTile(slot: slot),
                    if (slot != TaskSlot.night) const Divider(height: 20),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How Taska works',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your current windows are Morning ${SlotSchedule.labelForWindow(settings.slotWindows[TaskSlot.morning]!)}, Afternoon ${SlotSchedule.labelForWindow(settings.slotWindows[TaskSlot.afternoon]!)}, Evening ${SlotSchedule.labelForWindow(settings.slotWindows[TaskSlot.evening]!)}, and Night ${SlotSchedule.labelForWindow(settings.slotWindows[TaskSlot.night]!) }.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotWindowTile extends ConsumerWidget {
  const _SlotWindowTile({required this.slot});

  final TaskSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final window = settings.slotWindows[slot]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_slotLabel(slot), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: window.startHour,
                      minute: window.startMinute,
                    ),
                  );
                  if (picked == null) {
                    return;
                  }
                  await ref
                      .read(appSettingsProvider.notifier)
                      .updateSlotWindow(
                        slot,
                        window.copyWith(
                          startHour: picked.hour,
                          startMinute: picked.minute,
                        ),
                      );
                },
                icon: const Icon(Icons.login_rounded),
                label: Text(
                  'Start ${SlotSchedule.formatHourMinute(hour: window.startHour, minute: window.startMinute)}',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: window.endHour,
                      minute: window.endMinute,
                    ),
                  );
                  if (picked == null) {
                    return;
                  }
                  await ref
                      .read(appSettingsProvider.notifier)
                      .updateSlotWindow(
                        slot,
                        window.copyWith(
                          endHour: picked.hour,
                          endMinute: picked.minute,
                        ),
                      );
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(
                  'End ${SlotSchedule.formatHourMinute(hour: window.endHour, minute: window.endMinute)}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Current window: ${SlotSchedule.labelForWindow(window)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

String _intensityLabel(TaskReminderIntensity intensity) {
  return switch (intensity) {
    TaskReminderIntensity.low => 'Gentle',
    TaskReminderIntensity.normal => 'Balanced',
    TaskReminderIntensity.high => 'Persistent',
  };
}

String _slotLabel(TaskSlot slot) {
  return switch (slot) {
    TaskSlot.morning => 'Morning',
    TaskSlot.afternoon => 'Afternoon',
    TaskSlot.evening => 'Evening',
    TaskSlot.night => 'Night',
  };
}
