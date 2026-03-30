import 'package:sqflite/sqflite.dart';

import '../../../features/tasks/domain/entities/task_log.dart';
import '../models/achievement.dart';
import '../models/user_stats.dart';
import 'reward_repository.dart';

typedef DatabaseGetter = Future<Database> Function();

class RewardRepositoryImpl implements RewardRepository {
  RewardRepositoryImpl({required DatabaseGetter databaseGetter})
    : _databaseGetter = databaseGetter;

  final DatabaseGetter _databaseGetter;

  @override
  Future<UserStats> getUserStats() async {
    final db = await _databaseGetter();
    final rows = await db.query(
      'user_stats',
      where: 'id = ?',
      whereArgs: [UserStats.singletonId],
      limit: 1,
    );

    if (rows.isEmpty) {
      final initial = UserStats.initial();
      await saveUserStats(initial);
      return initial;
    }

    return UserStats.fromMap(rows.first);
  }

  @override
  Future<void> saveUserStats(UserStats stats) async {
    final db = await _databaseGetter();
    await db.insert(
      'user_stats',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<TaskLog>> getAllTaskLogs() async {
    final db = await _databaseGetter();
    final rows = await db.query(
      'task_logs',
      where: 'task_id IS NOT NULL',
      orderBy: 'logged_at ASC',
    );
    return rows.map(_taskLogFromMap).toList();
  }

  @override
  Future<List<TaskLog>> getTaskLogsForTask(int taskId) async {
    final db = await _databaseGetter();
    final rows = await db.query(
      'task_logs',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'logged_at ASC',
    );
    return rows.map(_taskLogFromMap).toList();
  }

  @override
  Future<List<Achievement>> getUnlockedAchievements() async {
    final db = await _databaseGetter();
    final rows = await db.query('achievements', orderBy: 'unlocked_at ASC');
    return rows.map(Achievement.fromMap).toList();
  }

  @override
  Future<void> unlockAchievement(Achievement achievement) async {
    final db = await _databaseGetter();
    await db.insert(
      'achievements',
      achievement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  TaskLog _taskLogFromMap(Map<String, Object?> map) {
    return TaskLog(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      action: map['action'] as String,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      metadata: map['metadata'] as String?,
    );
  }
}