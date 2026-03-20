import 'package:flutter_test/flutter_test.dart';

import 'package:taska/core/analytics/behavior_analytics.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';
import 'package:taska/features/tasks/domain/entities/task_log.dart';

void main() {
  const analytics = BehaviorAnalytics();

  test('suggests evening slot when completions mostly happen at night', () {
    final tasks = [
      _task(id: 1, slot: TaskSlot.morning),
      _task(id: 2, slot: TaskSlot.morning),
      _task(id: 3, slot: TaskSlot.afternoon),
    ];
    final logs = [
      _log(taskId: 1, action: 'completed', hour: 20),
      _log(taskId: 2, action: 'completed', hour: 20),
      _log(taskId: 3, action: 'completed', hour: 19),
      _log(taskId: 3, action: 'ignored', hour: 14),
    ];

    final insight = analytics.analyze(tasks: tasks, logs: logs);

    expect(insight.completionRate, closeTo(0.75, 0.001));
    expect(insight.mostActiveHour, 20);
    expect(insight.mostActiveSlot, TaskSlot.evening);
    expect(insight.suggestedSlot, TaskSlot.evening);
    expect(insight.suggestion, contains('8pm'));
    expect(insight.suggestion, contains('evening'));
  });

  test('warns when a slot is overloaded even without enough history', () {
    final tasks = [
      _task(id: 1, slot: TaskSlot.afternoon),
      _task(id: 2, slot: TaskSlot.afternoon),
      _task(id: 3, slot: TaskSlot.afternoon),
      _task(id: 4, slot: TaskSlot.afternoon),
      _task(
        id: 5,
        slot: TaskSlot.afternoon,
        status: TaskReminderStatus.completed,
      ),
    ];

    final insight = analytics.analyze(tasks: tasks, logs: const []);

    expect(insight.overloadWarning, isNotNull);
    expect(insight.overloadWarning, contains('afternoon'));
    expect(insight.suggestion, insight.overloadWarning);
  });
}

Task _task({
  required int id,
  required TaskSlot slot,
  TaskReminderStatus status = TaskReminderStatus.pending,
}) {
  return Task(
    id: id,
    title: 'Task $id',
    notes: null,
    timeLabel: '08:00',
    slot: slot,
    repeat: TaskRepeat.none,
    status: status,
    createdAt: DateTime(2026, 3, 20, 8),
    updatedAt: DateTime(2026, 3, 20, 8),
    nextReminderAt: DateTime(2026, 3, 20, 8),
    reminderIntervalMinutes: 180,
    reminderIntensity: TaskReminderIntensity.normal,
    ignoredCount: 0,
    completionRate: 0,
  );
}

TaskLog _log({required int taskId, required String action, required int hour}) {
  return TaskLog(
    taskId: taskId,
    action: action,
    loggedAt: DateTime(2026, 3, 20, hour),
  );
}
