import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taska/core/database/database_schema.dart';

void main() {
  late Database database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('creates tasks and task_logs tables', () async {
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    final names = tables.map((row) => row['name']).toSet();
    expect(names, contains('tasks'));
    expect(names, contains('shopping_items'));
    expect(names, contains('task_logs'));
    expect(names, contains('user_stats'));
    expect(names, contains('achievements'));
  });

  test('creates shopping_items table with expected columns', () async {
    final columns = await database.rawQuery('PRAGMA table_info(shopping_items)');
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('id'));
    expect(names, contains('name'));
    expect(names, contains('category'));
    expect(names, contains('is_completed'));
    expect(names, contains('linked_task_id'));
    expect(names, contains('session_id'));
    expect(names, contains('created_at'));
  });

  test('creates shopping_items foreign key to shopping_sessions', () async {
    final foreignKeys = await database.rawQuery(
      'PRAGMA foreign_key_list(shopping_items)',
    );

    expect(foreignKeys, isNotEmpty);
    expect(
      foreignKeys.any((row) => row['table'] == 'shopping_sessions'),
      isTrue,
    );
  });

  test('creates shopping_sessions table with expected columns', () async {
    final columns = await database.rawQuery(
      'PRAGMA table_info(shopping_sessions)',
    );
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('id'));
    expect(names, contains('date'));
    expect(names, contains('title'));
    expect(names, contains('status'));
    expect(names, contains('created_at'));
  });

  test('creates task_logs columns for shopping events', () async {
    final columns = await database.rawQuery('PRAGMA table_info(task_logs)');
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('task_id'));
    expect(names, contains('shopping_item_id'));
    expect(names, contains('action'));
    expect(names, contains('logged_at'));
    expect(names, contains('metadata'));
  });

  test('seeds a default user stats row', () async {
    final rows = await database.query('user_stats');
    expect(rows, hasLength(1));
    expect(rows.first['id'], 1);
    expect(rows.first['current_streak'], 0);
    expect(rows.first['longest_streak'], 0);
    expect(rows.first['last_completed_date'], isNull);
  });

  test('cascades log deletion when task is removed', () async {
    final taskId = await database.insert('tasks', {
      'title': 'Integrity',
      'notes': 'db',
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

    await database.insert('task_logs', {
      'task_id': taskId,
      'action': 'created',
      'logged_at': DateTime(2026, 1, 1).toIso8601String(),
      'metadata': null,
    });

    await database.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
    final logs = await database.query('task_logs');
    expect(logs, isEmpty);
  });

  test('rejects orphan task log inserts', () async {
    expect(
      () => database.insert('task_logs', {
        'task_id': 9999,
        'action': 'created',
        'logged_at': DateTime(2026, 1, 1).toIso8601String(),
        'metadata': null,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
