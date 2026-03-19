import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/task.dart';

final sampleTasksProvider = Provider<List<Task>>((ref) {
  return const [
    Task(
      id: 1,
      title: 'Plan tomorrow\'s study block',
      slot: TaskSlot.evening,
      status: TaskReminderStatus.pending,
    ),
    Task(
      id: 2,
      title: 'Review sprint priorities',
      slot: TaskSlot.morning,
      status: TaskReminderStatus.snoozed,
    ),
  ];
});
