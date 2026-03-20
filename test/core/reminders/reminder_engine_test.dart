import 'package:flutter_test/flutter_test.dart';

import 'package:taska/core/reminders/reminder_engine.dart';
import 'package:taska/core/scheduling/slot_schedule.dart';
import 'package:taska/core/settings/app_settings.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';
import 'package:taska/features/tasks/domain/entities/task_log.dart';

void main() {
  final engine = ReminderEngine(settings: AppSettings.defaults());
  final customSettingsEngine = ReminderEngine(
    settings: AppSettings.defaults().copyWith(
      defaultSnoozeMinutes: 15,
      preferredReminderIntensity: TaskReminderIntensity.high,
    ),
  );

  test('createInitialPlan keeps reminder inside selected slot window', () {
    final task = Task(
      title: 'Read',
      notes: null,
      timeLabel: '23:30',
      slot: TaskSlot.evening,
      repeat: TaskRepeat.none,
      status: TaskReminderStatus.pending,
      createdAt: DateTime(2026, 3, 20, 10),
      updatedAt: DateTime(2026, 3, 20, 10),
      nextReminderAt: DateTime(2026, 3, 20, 10),
      reminderIntervalMinutes: 180,
      reminderIntensity: TaskReminderIntensity.normal,
      ignoredCount: 0,
      completionRate: 0,
    );

    final planned = engine.createInitialPlan(task);

    expect(planned.timeLabel, '21:59');
    expect(planned.nextReminderAt.hour, 21);
    expect(planned.nextReminderAt.minute, 59);
  });

  test('weekday repeat skips weekend when computing next occurrence', () {
    final result = SlotSchedule.nextOccurrenceFromCompletion(
      completedAt: DateTime(2026, 3, 20, 18), // Friday
      timeLabel: '08:00',
      slot: TaskSlot.morning,
      repeat: TaskRepeat.weekdays,
    );

    expect(result.weekday, DateTime.monday);
    expect(result.hour, 8);
    expect(result.minute, 0);
  });

  test('applyCompletion keeps repeating tasks pending for next occurrence', () {
    final task = Task(
      id: 1,
      title: 'Workout',
      notes: null,
      timeLabel: '08:00',
      slot: TaskSlot.morning,
      repeat: TaskRepeat.daily,
      status: TaskReminderStatus.pending,
      createdAt: DateTime(2026, 3, 20, 7),
      updatedAt: DateTime(2026, 3, 20, 7),
      nextReminderAt: DateTime(2026, 3, 20, 8),
      reminderIntervalMinutes: 180,
      reminderIntensity: TaskReminderIntensity.normal,
      ignoredCount: 1,
      completionRate: 0.2,
    );

    final logs = [
      TaskLog(
        taskId: 1,
        action: 'completed',
        loggedAt: DateTime(2026, 3, 19, 8),
      ),
      TaskLog(taskId: 1, action: 'ignored', loggedAt: DateTime(2026, 3, 18, 8)),
    ];

    final updated = engine.applyCompletion(task, logs);

    expect(updated.status, TaskReminderStatus.pending);
    expect(updated.ignoredCount, 0);
    expect(updated.nextReminderAt.isAfter(DateTime.now()), isTrue);
  });

  test('applySnooze uses configured default snooze duration', () {
    final before = DateTime.now();
    final task = Task(
      id: 7,
      title: 'Stretch',
      notes: null,
      timeLabel: '07:30',
      slot: TaskSlot.morning,
      repeat: TaskRepeat.none,
      status: TaskReminderStatus.pending,
      createdAt: before,
      updatedAt: before,
      nextReminderAt: before,
      reminderIntervalMinutes: 180,
      reminderIntensity: TaskReminderIntensity.normal,
      ignoredCount: 0,
      completionRate: 0,
    );

    final updated = customSettingsEngine.applySnooze(task, const []);
    final snoozeMinutes = updated.nextReminderAt.difference(before).inMinutes;

    expect(snoozeMinutes, inInclusiveRange(14, 16));
    expect(updated.status, TaskReminderStatus.snoozed);
  });

  test('createInitialPlan honors preferred reminder intensity floor', () {
    final task = Task(
      title: 'Review plan',
      notes: null,
      timeLabel: '09:00',
      slot: TaskSlot.morning,
      repeat: TaskRepeat.none,
      status: TaskReminderStatus.pending,
      createdAt: DateTime(2026, 3, 20, 8),
      updatedAt: DateTime(2026, 3, 20, 8),
      nextReminderAt: DateTime(2026, 3, 20, 8),
      reminderIntervalMinutes: 180,
      reminderIntensity: TaskReminderIntensity.low,
      ignoredCount: 0,
      completionRate: 0,
    );

    final planned = customSettingsEngine.createInitialPlan(task);

    expect(planned.reminderIntensity, TaskReminderIntensity.high);
  });
}
