import 'package:flutter/material.dart';

import '../../domain/entities/task.dart';

List<Task> tasksForDate(List<Task> tasks, DateTime date) {
  final day = DateUtils.dateOnly(date);
  return tasks
      .where((task) => DateUtils.isSameDay(DateUtils.dateOnly(task.nextReminderAt), day))
      .toList();
}

Map<DateTime, int> taskCountsForMonth(List<Task> tasks, DateTime month) {
  final counts = <DateTime, int>{};
  for (final task in tasks) {
    final taskDate = DateUtils.dateOnly(task.nextReminderAt);
    if (taskDate.year != month.year || taskDate.month != month.month) {
      continue;
    }

    counts[taskDate] = (counts[taskDate] ?? 0) + 1;
  }

  return counts;
}