import '../../features/tasks/domain/entities/task.dart';
import '../../features/tasks/domain/entities/task_log.dart';

class BehaviorAnalytics {
  const BehaviorAnalytics();

  BehaviorInsight analyze({
    required List<Task> tasks,
    required List<TaskLog> logs,
  }) {
    final completionRate = _completionRate(logs);
    final mostActiveHour = _mostActiveHour(logs);
    final mostActiveSlot = mostActiveHour == null
        ? null
        : _slotForHour(mostActiveHour);
    final suggestedSlot = _suggestedSlot(tasks: tasks, logs: logs);
    final overloadWarning = _overloadWarning(tasks);
    final suggestion = _buildSuggestion(
      mostActiveHour: mostActiveHour,
      mostActiveSlot: mostActiveSlot,
      suggestedSlot: suggestedSlot,
      overloadWarning: overloadWarning,
    );

    return BehaviorInsight(
      completionRate: completionRate,
      mostActiveHour: mostActiveHour,
      mostActiveSlot: mostActiveSlot,
      suggestedSlot: suggestedSlot,
      overloadWarning: overloadWarning,
      suggestion: suggestion,
    );
  }

  double _completionRate(List<TaskLog> logs) {
    final completed = logs.where((log) => log.action == 'completed').length;
    final actionable = logs
        .where(
          (log) => {
            'completed',
            'ignored',
            'notification_snoozed',
          }.contains(log.action),
        )
        .length;
    if (actionable == 0) {
      return 0;
    }
    return completed / actionable;
  }

  int? _mostActiveHour(List<TaskLog> logs) {
    final completedLogs = logs
        .where((log) => log.action == 'completed')
        .toList();
    if (completedLogs.isEmpty) {
      return null;
    }

    final counts = <int, int>{};
    for (final log in completedLogs) {
      counts.update(log.loggedAt.hour, (value) => value + 1, ifAbsent: () => 1);
    }

    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  TaskSlot? _suggestedSlot({
    required List<Task> tasks,
    required List<TaskLog> logs,
  }) {
    final mostActiveHour = _mostActiveHour(logs);
    if (mostActiveHour == null) {
      return null;
    }

    final activeSlot = _slotForHour(mostActiveHour);
    final counts = <TaskSlot, int>{for (final slot in TaskSlot.values) slot: 0};

    for (final task in tasks) {
      counts.update(task.slot, (value) => value + 1);
    }

    final dominantCurrentSlot = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return dominantCurrentSlot == activeSlot ? null : activeSlot;
  }

  String? _overloadWarning(List<Task> tasks) {
    final counts = <TaskSlot, int>{for (final slot in TaskSlot.values) slot: 0};
    for (final task in tasks) {
      if (task.status != TaskReminderStatus.completed) {
        counts.update(task.slot, (value) => value + 1);
      }
    }

    final overloaded = counts.entries
        .where((entry) => entry.value >= 4)
        .toList();
    if (overloaded.isEmpty) {
      return null;
    }

    final slot = overloaded.first.key;
    return 'Your ${_slotLabel(slot).toLowerCase()} slot looks overloaded. Consider moving 1-2 tasks.';
  }

  String _buildSuggestion({
    required int? mostActiveHour,
    required TaskSlot? mostActiveSlot,
    required TaskSlot? suggestedSlot,
    required String? overloadWarning,
  }) {
    if (suggestedSlot != null &&
        mostActiveHour != null &&
        mostActiveSlot != null) {
      return 'You complete tasks most often around ${_formatHour(mostActiveHour)}. Try using the ${_slotLabel(suggestedSlot).toLowerCase()} slot more.';
    }
    if (overloadWarning != null) {
      return overloadWarning;
    }
    if (mostActiveHour != null && mostActiveSlot != null) {
      return 'Your strongest completion window is around ${_formatHour(mostActiveHour)} in the ${_slotLabel(mostActiveSlot).toLowerCase()}.';
    }
    return 'Complete a few tasks and the app will start suggesting better slots.';
  }

  TaskSlot _slotForHour(int hour) {
    if (hour >= 22 || hour < 6) {
      return TaskSlot.night;
    }
    if (hour >= 6 && hour < 12) {
      return TaskSlot.morning;
    }
    if (hour >= 12 && hour < 17) {
      return TaskSlot.afternoon;
    }
    return TaskSlot.evening;
  }

  String _slotLabel(TaskSlot slot) {
    switch (slot) {
      case TaskSlot.morning:
        return 'Morning';
      case TaskSlot.afternoon:
        return 'Afternoon';
      case TaskSlot.evening:
        return 'Evening';
      case TaskSlot.night:
        return 'Night';
    }
  }

  String _formatHour(int hour) {
    final suffix = hour >= 12 ? 'pm' : 'am';
    final normalized = hour % 12 == 0 ? 12 : hour % 12;
    return '$normalized$suffix';
  }
}

class BehaviorInsight {
  const BehaviorInsight({
    required this.completionRate,
    required this.mostActiveHour,
    required this.mostActiveSlot,
    required this.suggestedSlot,
    required this.overloadWarning,
    required this.suggestion,
  });

  final double completionRate;
  final int? mostActiveHour;
  final TaskSlot? mostActiveSlot;
  final TaskSlot? suggestedSlot;
  final String? overloadWarning;
  final String suggestion;
}
