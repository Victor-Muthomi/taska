import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taska/core/database/database_schema.dart';
import 'package:taska/core/notifications/notification_service.dart';
import 'package:taska/core/rewards/repository/reward_repository_impl.dart';
import 'package:taska/core/rewards/services/reward_engine.dart';

Future<void> seedTask(Database db, int id, String title) async {
  await db.insert('tasks', {
    'id': id,
    'title': title,
    'notes': null,
    'time_label': '08:00',
    'slot': 'morning',
    'repeat_pattern': 'none',
    'status': 'pending',
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
    'updated_at': DateTime(2026, 1, 1).toIso8601String(),
    'next_reminder_at': DateTime(2026, 1, 1, 8).toIso8601String(),
    'reminder_interval_minutes': 180,
    'reminder_intensity': 'normal',
    'ignored_count': 0,
    'completion_rate': 0.0,
    'last_reminder_at': null,
  });
}

Future<void> logCompletion(
  Database db, {
  required int taskId,
  required DateTime day,
  int offset = 0,
}) async {
  await db.insert('task_logs', {
    'task_id': taskId,
    'action': 'completed',
    'logged_at': day.add(Duration(minutes: offset)).toIso8601String(),
    'metadata': null,
  });
}

Future<void> logSnooze(
  Database db, {
  required int taskId,
  required DateTime day,
  required int offset,
}) async {
  await db.insert('task_logs', {
    'task_id': taskId,
    'action': 'snoozed',
    'logged_at': day.add(Duration(minutes: offset)).toIso8601String(),
    'metadata': null,
  });
}

void main() {
  late Database database;
  late String databasePath;
  late RewardEngine engine;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databasePath = path.join(
      Directory.systemTemp.path,
      'taska_reward_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    database = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );

    engine = RewardEngine(
      repository: RewardRepositoryImpl(databaseGetter: () async => database),
    );
  });

  tearDown(() async {
    await database.close();
    await File(databasePath).delete();
  });

  test('computes streaks and unlocks achievements from task logs', () async {
    await seedTask(database, 1, 'Task 1');
    await seedTask(database, 2, 'Task 2');
    await seedTask(database, 3, 'Task 3');
    await seedTask(database, 4, 'Task 4');
    await seedTask(database, 5, 'Task 5');
    await seedTask(database, 6, 'Task 6');
    await seedTask(database, 7, 'Task 7');
    await seedTask(database, 8, 'Task 8');
    await seedTask(database, 9, 'Task 9');

    await logCompletion(database, taskId: 1, day: DateTime(2026, 1, 1));
    await logCompletion(database, taskId: 2, day: DateTime(2026, 1, 4));
    await logCompletion(database, taskId: 3, day: DateTime(2026, 1, 5));
    await logCompletion(database, taskId: 4, day: DateTime(2026, 1, 6));
    await logCompletion(database, taskId: 5, day: DateTime(2026, 1, 6));
    await logCompletion(database, taskId: 6, day: DateTime(2026, 1, 6));
    await logCompletion(database, taskId: 7, day: DateTime(2026, 1, 6));
    await logCompletion(database, taskId: 8, day: DateTime(2026, 1, 6));
    await logSnooze(database, taskId: 9, day: DateTime(2026, 1, 6), offset: 1);
    await logSnooze(database, taskId: 9, day: DateTime(2026, 1, 6), offset: 2);
    await logSnooze(database, taskId: 9, day: DateTime(2026, 1, 6), offset: 3);
    await logCompletion(database, taskId: 9, day: DateTime(2026, 1, 6), offset: 4);

    await engine.refreshFromLogs(today: DateTime(2026, 1, 6));

    final stats = await engine.getUserStats();
    expect(stats.currentStreak, 3);
    expect(stats.longestStreak, 3);
    expect(stats.lastCompletedDate, DateTime(2026, 1, 6));

    final achievements = await engine.getUnlockedAchievements();
    final ids = achievements.map((achievement) => achievement.id).toSet();

    expect(ids, contains('consistency_starter'));
    expect(ids, contains('focused_mind'));
    expect(ids, contains('resilient'));
    expect(ids, contains('comeback'));
    expect(ids, isNot(contains('on_fire')));
  });

  test('keeps achievement unlocks idempotent across repeated syncs', () async {
    await seedTask(database, 1, 'Task 1');
    await logCompletion(database, taskId: 1, day: DateTime(2026, 1, 6));
    await logCompletion(database, taskId: 1, day: DateTime(2026, 1, 5));
    await logCompletion(database, taskId: 1, day: DateTime(2026, 1, 4));

    await engine.refreshFromLogs(today: DateTime(2026, 1, 6));
    await engine.refreshFromLogs(today: DateTime(2026, 1, 6));

    final achievements = await engine.getUnlockedAchievements();
    expect(achievements.where((achievement) => achievement.id == 'consistency_starter'), hasLength(1));
    expect(achievements.where((achievement) => achievement.id == 'on_fire'), isEmpty);
  });

  test('schedules a comeback reminder after two inactive days', () async {
    await seedTask(database, 1, 'Task 1');
    await logCompletion(database, taskId: 1, day: DateTime(2026, 1, 4));

    final notificationService = _FakeRewardNotificationService();
    engine = RewardEngine(
      repository: RewardRepositoryImpl(databaseGetter: () async => database),
      notificationService: notificationService,
    );

    await engine.refreshFromLogs(today: DateTime(2026, 1, 6));

    expect(notificationService.scheduledAt, DateTime(2026, 1, 6));
  });

}

class _FakeRewardNotificationService extends NotificationService {
  DateTime? scheduledAt;
  int cancelCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleComebackReminder({required DateTime scheduledAt}) async {
    this.scheduledAt = scheduledAt;
  }

  @override
  Future<void> cancelComebackReminder() async {
    cancelCount += 1;
  }
}