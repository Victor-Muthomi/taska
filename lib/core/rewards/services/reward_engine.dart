import '../../../features/tasks/domain/entities/task_log.dart';
import '../../notifications/notification_service.dart';
import '../models/achievement.dart';
import '../models/user_stats.dart';
import '../repository/reward_repository.dart';

class RewardEngine {
  RewardEngine({
    required RewardRepository repository,
    NotificationService? notificationService,
  })  : _repository = repository,
        _notificationService = notificationService;

  static const String consistencyStarterId = 'consistency_starter';
  static const String onFireId = 'on_fire';
  static const String focusedMindId = 'focused_mind';
  static const String resilientId = 'resilient';
  static const String comebackId = 'comeback';

  final RewardRepository _repository;
  final NotificationService? _notificationService;

  UserStats? _cachedUserStats;
  List<Achievement>? _cachedUnlockedAchievements;

  Future<UserStats> updateStreak(DateTime today) async {
    await refreshFromLogs(today: today);
    return getUserStats();
  }

  Future<void> evaluateAchievements(TaskLog log) async {
    await refreshFromLogs(today: log.loggedAt);
  }

  Future<void> unlockAchievement(String id) async {
    final definition = _achievementDefinitions[id];
    if (definition == null) {
      return;
    }

    final achievement = Achievement(
      id: id,
      title: definition.title,
      description: definition.description,
      unlockedAt: DateTime.now(),
    );
    await _repository.unlockAchievement(achievement);
    _cachedUnlockedAchievements = null;
  }

  Future<List<Achievement>> getUnlockedAchievements() async {
    final cachedAchievements = _cachedUnlockedAchievements;
    if (cachedAchievements != null) {
      return cachedAchievements;
    }

    final unlockedAchievements = await _repository.getUnlockedAchievements();
    _cachedUnlockedAchievements = unlockedAchievements;
    return unlockedAchievements;
  }

  Future<UserStats> getUserStats() async {
    final cachedStats = _cachedUserStats;
    if (cachedStats != null) {
      return cachedStats;
    }

    final userStats = await _repository.getUserStats();
    _cachedUserStats = userStats;
    return userStats;
  }

  Future<double> getWeeklyCompletionScore() async {
    final logs = await _repository.getAllTaskLogs();
    final today = _dateOnly(DateTime.now());
    final windowStart = today.subtract(const Duration(days: 6));
    final completedDays = <String>{};

    for (final log in logs) {
      if (!_isCompletion(log.action)) {
        continue;
      }

      final day = _dateOnly(log.loggedAt);
      if (day.isBefore(windowStart) || day.isAfter(today)) {
        continue;
      }

      completedDays.add(_dateKey(day));
    }

    return (completedDays.length / 7.0) * 100.0;
  }

  Future<void> refreshFromLogs({DateTime? today}) async {
    final logs = await _repository.getAllTaskLogs();
    final currentDay = _dateOnly(today ?? DateTime.now());
    final computedStats = _calculateStats(logs, currentDay);
    await _repository.saveUserStats(computedStats);
    _cachedUserStats = computedStats;

    final achievementIds = _determineUnlockedAchievementIds(logs, computedStats);
    for (final achievementId in achievementIds) {
      await unlockAchievement(achievementId);
    }

    _cachedUnlockedAchievements = await _repository.getUnlockedAchievements();
    await _syncComebackReminder(logs);
  }

  UserStats _calculateStats(List<TaskLog> logs, DateTime today) {
    final completedDates = <String>{};
    for (final log in logs) {
      if (_isCompletion(log.action)) {
        completedDates.add(_dateKey(_dateOnly(log.loggedAt)));
      }
    }

    if (completedDates.isEmpty) {
      return UserStats.initial();
    }

    final sortedDates = completedDates.toList()..sort();
    final longestStreak = _longestStreak(sortedDates);
    final currentStreak = _currentStreak(sortedDates, today);
    final latestCompletedDate = _parseDateKey(sortedDates.last);

    return UserStats(
      id: UserStats.singletonId,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastCompletedDate: latestCompletedDate,
    );
  }

  int _currentStreak(List<String> sortedDateKeys, DateTime today) {
    final completedDays = sortedDateKeys.toSet();
    final todayKey = _dateKey(today);
    if (!completedDays.contains(todayKey)) {
      return 0;
    }

    var streak = 1;
    var cursor = today.subtract(const Duration(days: 1));
    while (completedDays.contains(_dateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  int _longestStreak(List<String> sortedDateKeys) {
    if (sortedDateKeys.isEmpty) {
      return 0;
    }

    var longestStreak = 1;
    var currentStreak = 1;
    DateTime previousDate = _parseDateKey(sortedDateKeys.first);

    for (var index = 1; index < sortedDateKeys.length; index++) {
      final currentDate = _parseDateKey(sortedDateKeys[index]);
      if (currentDate.difference(previousDate).inDays == 1) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
      previousDate = currentDate;
    }

    return longestStreak;
  }

  Set<String> _determineUnlockedAchievementIds(
    List<TaskLog> logs,
    UserStats stats,
  ) {
    final unlockedIds = <String>{};

    if (stats.currentStreak >= 3) {
      unlockedIds.add(consistencyStarterId);
    }
    if (stats.currentStreak >= 7) {
      unlockedIds.add(onFireId);
    }
    if (_hasFocusedMindAchievement(logs)) {
      unlockedIds.add(focusedMindId);
    }
    if (_hasResilientAchievement(logs)) {
      unlockedIds.add(resilientId);
    }
    if (_hasComebackAchievement(logs)) {
      unlockedIds.add(comebackId);
    }

    return unlockedIds;
  }

  bool _hasFocusedMindAchievement(List<TaskLog> logs) {
    final completionsByDay = <String, Set<int>>{};

    for (final log in logs) {
      if (!_isCompletion(log.action)) {
        continue;
      }

      final dayKey = _dateKey(_dateOnly(log.loggedAt));
      completionsByDay.putIfAbsent(dayKey, () => <int>{}).add(log.taskId);
      if (completionsByDay[dayKey]!.length >= 5) {
        return true;
      }
    }

    return false;
  }

  bool _hasResilientAchievement(List<TaskLog> logs) {
    final logsByTask = <int, List<TaskLog>>{};
    for (final log in logs) {
      logsByTask.putIfAbsent(log.taskId, () => <TaskLog>[]).add(log);
    }

    for (final taskLogs in logsByTask.values) {
      var snoozeCount = 0;
      for (final log in taskLogs) {
        if (_isSnooze(log.action)) {
          snoozeCount += 1;
          continue;
        }

        if (_isCompletion(log.action)) {
          if (snoozeCount >= 3) {
            return true;
          }
          snoozeCount = 0;
          continue;
        }

        if (_isResilientResetAction(log.action)) {
          snoozeCount = 0;
        }
      }
    }

    return false;
  }

  bool _hasComebackAchievement(List<TaskLog> logs) {
    final completedDates = <String>{};
    for (final log in logs) {
      if (_isCompletion(log.action)) {
        completedDates.add(_dateKey(_dateOnly(log.loggedAt)));
      }
    }

    final sortedDates = completedDates.toList()..sort();
    if (sortedDates.length < 2) {
      return false;
    }

    var previousDate = _parseDateKey(sortedDates.first);
    for (var index = 1; index < sortedDates.length; index++) {
      final currentDate = _parseDateKey(sortedDates[index]);
      if (currentDate.difference(previousDate).inDays >= 3) {
        return true;
      }
      previousDate = currentDate;
    }

    return false;
  }

  bool _isCompletion(String action) {
    final normalizedAction = _normalizeAction(action);
    return normalizedAction == 'completed' || normalizedAction == 'done';
  }

  bool _isSnooze(String action) {
    final normalizedAction = _normalizeAction(action);
    return normalizedAction == 'snoozed';
  }

  bool _isResilientResetAction(String action) {
    final normalizedAction = _normalizeAction(action);
    return normalizedAction == 'created' ||
        normalizedAction == 'ignored' ||
        normalizedAction == 'deleted';
  }

  String _normalizeAction(String action) {
    final normalizedAction = action.trim().toLowerCase();
    switch (normalizedAction) {
      case 'done':
      case 'completed':
        return 'completed';
      case 'snoozed':
      case 'notification_snoozed':
        return 'snoozed';
      case 'notification_unsnoozed':
      case 'notification_scheduled':
      case 'notification_cancelled':
      case 'notification_opened':
      case 'updated':
      case 'created':
      case 'ignored':
      case 'deleted':
        return normalizedAction;
      default:
        return normalizedAction;
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _dateKey(DateTime value) {
    return _dateOnly(value).toIso8601String();
  }

  DateTime _parseDateKey(String value) {
    return DateTime.parse(value);
  }

  Future<void> _syncComebackReminder(List<TaskLog> logs) async {
    final notificationService = _notificationService;
    if (notificationService == null) {
      return;
    }

    if (logs.isEmpty) {
      await notificationService.cancelComebackReminder();
      return;
    }

    final latestActivity = logs.reduce(
      (current, next) =>
          current.loggedAt.isAfter(next.loggedAt) ? current : next,
    );
    await notificationService.scheduleComebackReminder(
      scheduledAt: latestActivity.loggedAt.add(const Duration(days: 2)),
    );
  }

  final Map<String, _AchievementDefinition> _achievementDefinitions = {
    consistencyStarterId: const _AchievementDefinition(
      title: 'Consistency Starter',
      description: 'Complete at least one task for 3 consecutive days.',
    ),
    onFireId: const _AchievementDefinition(
      title: 'On Fire',
      description: 'Complete at least one task for 7 consecutive days.',
    ),
    focusedMindId: const _AchievementDefinition(
      title: 'Focused Mind',
      description: 'Complete 5 tasks in a single day.',
    ),
    resilientId: const _AchievementDefinition(
      title: 'Resilient',
      description: 'Complete a task after 3 snoozes.',
    ),
    comebackId: const _AchievementDefinition(
      title: 'Comeback',
      description: 'Return and complete a task after 2 or more missed days.',
    ),
  };
}

class _AchievementDefinition {
  const _AchievementDefinition({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

/// Example usage:
/// final rewardEngine = ref.read(rewardEngineProvider);
/// await rewardEngine.evaluateAchievements(
///   TaskLog(taskId: task.id!, action: 'completed', loggedAt: DateTime.now()),
/// );
/// final stats = await rewardEngine.getUserStats();
/// final achievements = await rewardEngine.getUnlockedAchievements();