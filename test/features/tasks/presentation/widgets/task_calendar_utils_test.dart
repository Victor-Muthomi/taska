import 'package:flutter_test/flutter_test.dart';

import 'package:taska/features/tasks/domain/entities/task.dart';
import 'package:taska/features/tasks/presentation/widgets/task_calendar_utils.dart';

void main() {
  test('tasksForDate matches tasks by reminder day', () {
    final tasks = [
      _task(id: 1, title: 'Today task', nextReminderAt: DateTime(2026, 3, 20, 9)),
      _task(id: 2, title: 'Tomorrow task', nextReminderAt: DateTime(2026, 3, 21, 9)),
    ];

    final todayTasks = tasksForDate(tasks, DateTime(2026, 3, 20, 12));
    final tomorrowTasks = tasksForDate(tasks, DateTime(2026, 3, 21, 12));

    expect(todayTasks.map((task) => task.title), ['Today task']);
    expect(tomorrowTasks.map((task) => task.title), ['Tomorrow task']);
  });

  test('taskCountsForMonth counts all tasks on their reminder day', () {
    final tasks = [
      _task(id: 1, title: 'One', nextReminderAt: DateTime(2026, 3, 20, 9)),
      _task(id: 2, title: 'Two', nextReminderAt: DateTime(2026, 3, 20, 14)),
      _task(id: 3, title: 'Three', nextReminderAt: DateTime(2026, 3, 21, 9)),
    ];

    final counts = taskCountsForMonth(tasks, DateTime(2026, 3, 1));

    expect(counts[DateTime(2026, 3, 20)], 2);
    expect(counts[DateTime(2026, 3, 21)], 1);
  });
}

Task _task({
  required int id,
  required String title,
  required DateTime nextReminderAt,
}) {
  return Task(
    id: id,
    title: title,
    notes: null,
    timeLabel: '08:00',
    slot: TaskSlot.morning,
    repeat: TaskRepeat.none,
    status: TaskReminderStatus.pending,
    createdAt: nextReminderAt,
    updatedAt: nextReminderAt,
    nextReminderAt: nextReminderAt,
    reminderIntervalMinutes: 180,
    reminderIntensity: TaskReminderIntensity.normal,
    ignoredCount: 0,
    completionRate: 0,
  );
}