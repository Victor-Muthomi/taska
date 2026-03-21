import '../scheduling/slot_schedule.dart';
import '../../features/tasks/domain/entities/task.dart';
import '../../features/tasks/domain/entities/task_log.dart';
import '../settings/app_settings.dart';

class ReminderEngine {
  const ReminderEngine({required this.settings});

  final AppSettings settings;

  Task createInitialPlan(Task task) {
    final normalizedTime = SlotSchedule.normalizeTimeForSlot(
      task.timeLabel,
      task.slot,
    );
    return task.copyWith(
      timeLabel: normalizedTime,
      nextReminderAt: SlotSchedule.nextDateTimeForTask(
        timeLabel: normalizedTime,
        slot: task.slot,
        repeat: task.repeat,
        from: task.createdAt,
      ),
      reminderIntervalMinutes: _baseInterval(task.slot),
      reminderIntensity: settings.preferredReminderIntensity,
      ignoredCount: 0,
      completionRate: 0,
    );
  }

  Task applyCompletion(Task task, List<TaskLog> logs) {
    final now = DateTime.now();
    final completionRate = computeCompletionRate(
      logs,
      includeCompletionBoost: true,
    );
    final nextStatus = task.repeat == TaskRepeat.none
        ? TaskReminderStatus.completed
        : TaskReminderStatus.pending;
    final nextReminderAt = task.repeat == TaskRepeat.none
        ? task.nextReminderAt
        : SlotSchedule.nextOccurrenceFromCompletion(
            completedAt: now,
            timeLabel: task.timeLabel,
            slot: task.slot,
            repeat: task.repeat,
          );

    return task.copyWith(
      status: nextStatus,
      completionRate: completionRate,
      ignoredCount: 0,
      reminderIntervalMinutes: _calibrateInterval(
        currentInterval: task.reminderIntervalMinutes,
        completionRate: completionRate,
        ignoredCount: 0,
        logs: logs,
      ),
      reminderIntensity: _calibrateIntensity(
        completionRate: completionRate,
        ignoredCount: 0,
        logs: logs,
      ),
      nextReminderAt: nextReminderAt,
      lastReminderAt: now,
      updatedAt: now,
    );
  }

  Task applySnooze(Task task, List<TaskLog> logs) {
    final completionRate = computeCompletionRate(logs);
    return task.copyWith(
      status: TaskReminderStatus.snoozed,
      nextReminderAt: DateTime.now().add(
        Duration(minutes: settings.defaultSnoozeMinutes),
      ),
      reminderIntervalMinutes: _calibrateInterval(
        currentInterval: task.reminderIntervalMinutes,
        completionRate: completionRate,
        ignoredCount: task.ignoredCount,
        snoozed: true,
        logs: logs,
      ),
      reminderIntensity: _calibrateIntensity(
        completionRate: completionRate,
        ignoredCount: task.ignoredCount,
        snoozed: true,
        logs: logs,
      ),
      completionRate: completionRate,
      updatedAt: DateTime.now(),
    );
  }

  Task applyUnsnooze(Task task, List<TaskLog> logs) {
    return scheduleNextReminder(task, logs);
  }

  Task applyIgnored(Task task, List<TaskLog> logs) {
    final ignoredCount = task.ignoredCount + 1;
    final completionRate = computeCompletionRate(logs);
    final interval = _calibrateInterval(
      currentInterval: task.reminderIntervalMinutes,
      completionRate: completionRate,
      ignoredCount: ignoredCount,
      ignored: true,
      logs: logs,
    );

    return task.copyWith(
      status: TaskReminderStatus.ignored,
      ignoredCount: ignoredCount,
      completionRate: completionRate,
      reminderIntervalMinutes: interval,
      reminderIntensity: _calibrateIntensity(
        completionRate: completionRate,
        ignoredCount: ignoredCount,
        ignored: true,
        logs: logs,
      ),
      lastReminderAt: DateTime.now(),
      nextReminderAt: DateTime.now().add(Duration(minutes: interval)),
      updatedAt: DateTime.now(),
    );
  }

  Task scheduleNextReminder(Task task, List<TaskLog> logs) {
    final completionRate = computeCompletionRate(logs);
    final interval = _calibrateInterval(
      currentInterval: task.reminderIntervalMinutes,
      completionRate: completionRate,
      ignoredCount: task.ignoredCount,
      logs: logs,
    );

    return task.copyWith(
      status: TaskReminderStatus.pending,
      completionRate: completionRate,
      reminderIntervalMinutes: interval,
      reminderIntensity: _calibrateIntensity(
        completionRate: completionRate,
        ignoredCount: task.ignoredCount,
        logs: logs,
      ),
      nextReminderAt: DateTime.now().add(Duration(minutes: interval)),
      lastReminderAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  bool isMissed(Task task, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    return task.status != TaskReminderStatus.completed &&
        task.nextReminderAt.isBefore(
          clock.subtract(const Duration(minutes: 5)),
        );
  }

  double computeCompletionRate(
    List<TaskLog> logs, {
    bool includeCompletionBoost = false,
  }) {
    final completed = logs
        .where((log) => log.action == 'completed' || log.action == 'done')
        .length;
    final attempts = logs
        .where(
          (log) => {
            'completed',
            'done',
            'notification_snoozed',
            'ignored',
            'notification_opened',
          }.contains(log.action),
        )
        .length;

    if (attempts == 0 && !includeCompletionBoost) {
      return 0;
    }

    final numerator = completed + (includeCompletionBoost ? 1 : 0);
    final denominator = attempts + (includeCompletionBoost ? 1 : 0);
    return (numerator / denominator).clamp(0, 1).toDouble();
  }

  ReminderSnapshot snapshot(Task task) {
    return ReminderSnapshot(
      completionRate: task.completionRate,
      ignoredCount: task.ignoredCount,
      reminderIntervalMinutes: task.reminderIntervalMinutes,
      intensity: task.reminderIntensity,
      nextReminderAt: task.nextReminderAt,
    );
  }

  int _baseInterval(TaskSlot slot) {
    return switch (slot) {
      TaskSlot.morning => 180,
      TaskSlot.afternoon => 150,
      TaskSlot.evening => 120,
    };
  }

  int _calibrateInterval({
    required int currentInterval,
    required double completionRate,
    required int ignoredCount,
    required List<TaskLog> logs,
    bool snoozed = false,
    bool ignored = false,
  }) {
    var interval = currentInterval;
    final recentIgnored = logs
        .take(6)
        .where((log) => log.action == 'ignored')
        .length;
    final recentCompleted = logs
        .take(6)
        .where((log) => log.action == 'completed')
        .length;

    if (ignored) {
      interval = (interval * 0.65).round();
    } else if (snoozed) {
      interval = (interval * 0.85).round();
    } else if (completionRate >= 0.75) {
      interval = (interval * 1.15).round();
    }

    interval -= (ignoredCount * 5) + (recentIgnored * 4);
    interval += recentCompleted * 3;
    return interval.clamp(15, 240);
  }

  TaskReminderIntensity _calibrateIntensity({
    required double completionRate,
    required int ignoredCount,
    required List<TaskLog> logs,
    bool snoozed = false,
    bool ignored = false,
  }) {
    final recentIgnored = logs
        .take(5)
        .where((log) => log.action == 'ignored')
        .length;
    final recentCompleted = logs
        .take(5)
        .where((log) => log.action == 'completed')
        .length;

    if (ignored ||
        ignoredCount >= 2 ||
        recentIgnored >= 2 ||
        completionRate < 0.35) {
      return _applyPreferredIntensity(TaskReminderIntensity.high);
    }
    if (snoozed || ignoredCount == 1 || completionRate < 0.65) {
      return _applyPreferredIntensity(TaskReminderIntensity.normal);
    }
    if (recentCompleted >= 3 && completionRate >= 0.8) {
      return _applyPreferredIntensity(TaskReminderIntensity.low);
    }
    return _applyPreferredIntensity(TaskReminderIntensity.low);
  }

  TaskReminderIntensity _applyPreferredIntensity(
    TaskReminderIntensity adaptive,
  ) {
    return adaptive.index < settings.preferredReminderIntensity.index
        ? settings.preferredReminderIntensity
        : adaptive;
  }
}

class ReminderSnapshot {
  const ReminderSnapshot({
    required this.completionRate,
    required this.ignoredCount,
    required this.reminderIntervalMinutes,
    required this.intensity,
    required this.nextReminderAt,
  });

  final double completionRate;
  final int ignoredCount;
  final int reminderIntervalMinutes;
  final TaskReminderIntensity intensity;
  final DateTime nextReminderAt;
}
