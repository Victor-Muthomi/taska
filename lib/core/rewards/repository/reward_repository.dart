import '../../../features/tasks/domain/entities/task_log.dart';
import '../models/achievement.dart';
import '../models/user_stats.dart';

abstract class RewardRepository {
  Future<UserStats> getUserStats();

  Future<void> saveUserStats(UserStats stats);

  Future<List<TaskLog>> getAllTaskLogs();

  Future<List<TaskLog>> getTaskLogsForTask(int taskId);

  Future<List<Achievement>> getUnlockedAchievements();

  Future<void> unlockAchievement(Achievement achievement);
}