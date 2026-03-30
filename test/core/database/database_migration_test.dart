import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taska/core/database/database_schema.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('upgrades version 1 schema to latest task columns', () async {
    final dbPath = path.join(
      Directory.systemTemp.path,
      'taska_v1_upgrade_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final oldDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              notes TEXT,
              slot TEXT NOT NULL,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE task_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              task_id INTEGER NOT NULL,
              action TEXT NOT NULL,
              logged_at TEXT NOT NULL,
              metadata TEXT
            )
          ''');
        },
      ),
    );
    await oldDb.close();

    final upgradedDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );

    final columns = await upgradedDb.rawQuery("PRAGMA table_info(tasks)");
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('time_label'));
    expect(names, contains('repeat_pattern'));
    expect(names, contains('next_reminder_at'));
    expect(names, contains('reminder_intensity'));
    expect(names, contains('completion_rate'));

    await upgradedDb.close();
    await File(dbPath).delete();
  });

  test('upgrades version 2 schema to include time and repeat fields', () async {
    final dbPath = path.join(
      Directory.systemTemp.path,
      'taska_v2_upgrade_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final oldDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              notes TEXT,
              slot TEXT NOT NULL,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              next_reminder_at TEXT NOT NULL,
              reminder_interval_minutes INTEGER NOT NULL DEFAULT 180,
              reminder_intensity TEXT NOT NULL DEFAULT 'normal',
              ignored_count INTEGER NOT NULL DEFAULT 0,
              completion_rate REAL NOT NULL DEFAULT 0,
              last_reminder_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE task_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              task_id INTEGER NOT NULL,
              action TEXT NOT NULL,
              logged_at TEXT NOT NULL,
              metadata TEXT
            )
          ''');
        },
      ),
    );
    await oldDb.close();

    final upgradedDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );

    final columns = await upgradedDb.rawQuery("PRAGMA table_info(tasks)");
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('time_label'));
    expect(names, contains('repeat_pattern'));

    await upgradedDb.close();
    await File(dbPath).delete();
  });

  test('upgrades version 3 logs table to enforce foreign keys', () async {
    final dbPath = path.join(
      Directory.systemTemp.path,
      'taska_v3_upgrade_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final oldDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              notes TEXT,
              time_label TEXT NOT NULL,
              slot TEXT NOT NULL,
              repeat_pattern TEXT NOT NULL DEFAULT 'none',
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              next_reminder_at TEXT NOT NULL,
              reminder_interval_minutes INTEGER NOT NULL DEFAULT 180,
              reminder_intensity TEXT NOT NULL DEFAULT 'normal',
              ignored_count INTEGER NOT NULL DEFAULT 0,
              completion_rate REAL NOT NULL DEFAULT 0,
              last_reminder_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE task_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              task_id INTEGER NOT NULL,
              action TEXT NOT NULL,
              logged_at TEXT NOT NULL,
              metadata TEXT
            )
          ''');
        },
      ),
    );

    final taskId = await oldDb.insert('tasks', {
      'title': 'Upgrade',
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
    await oldDb.insert('task_logs', {
      'task_id': taskId,
      'action': 'created',
      'logged_at': DateTime(2026, 1, 1).toIso8601String(),
      'metadata': null,
    });
    await oldDb.insert('task_logs', {
      'task_id': 999999,
      'action': 'orphaned',
      'logged_at': DateTime(2026, 1, 1).toIso8601String(),
      'metadata': null,
    });
    await oldDb.close();

    final upgradedDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );

    final foreignKeys = await upgradedDb.rawQuery(
      'PRAGMA foreign_key_list(task_logs)',
    );
    final logs = await upgradedDb.query('task_logs');

    expect(foreignKeys, isNotEmpty);
    expect(logs.length, 1);

    await upgradedDb.close();
    await File(dbPath).delete();
  });

  test('upgrades version 6 schema to include shopping items table', () async {
    final dbPath = path.join(
      Directory.systemTemp.path,
      'taska_v6_upgrade_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final oldDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              notes TEXT,
              time_label TEXT NOT NULL,
              type TEXT NOT NULL DEFAULT 'normal',
              slot TEXT NOT NULL,
              repeat_pattern TEXT NOT NULL DEFAULT 'none',
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              next_reminder_at TEXT NOT NULL,
              reminder_interval_minutes INTEGER NOT NULL DEFAULT 180,
              reminder_intensity TEXT NOT NULL DEFAULT 'normal',
              ignored_count INTEGER NOT NULL DEFAULT 0,
              completion_rate REAL NOT NULL DEFAULT 0,
              last_reminder_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE task_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              task_id INTEGER NOT NULL,
              action TEXT NOT NULL,
              logged_at TEXT NOT NULL,
              metadata TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE user_stats (
              id INTEGER PRIMARY KEY,
              current_streak INTEGER NOT NULL DEFAULT 0,
              longest_streak INTEGER NOT NULL DEFAULT 0,
              last_completed_date TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE achievements (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              unlocked_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await oldDb.close();

    final upgradedDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );

    final columns = await upgradedDb.rawQuery(
      'PRAGMA table_info(shopping_items)',
    );
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('id'));
    expect(names, contains('name'));
    expect(names, contains('category'));
    expect(names, contains('is_completed'));
    expect(names, contains('linked_task_id'));
    expect(names, contains('created_at'));

    await upgradedDb.close();
    await File(dbPath).delete();
  });

  test('upgrades version 7 schema to support shopping task logs', () async {
    final dbPath = path.join(
      Directory.systemTemp.path,
      'taska_v7_upgrade_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final oldDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              notes TEXT,
              time_label TEXT NOT NULL,
              type TEXT NOT NULL DEFAULT 'normal',
              slot TEXT NOT NULL,
              repeat_pattern TEXT NOT NULL DEFAULT 'none',
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              next_reminder_at TEXT NOT NULL,
              reminder_interval_minutes INTEGER NOT NULL DEFAULT 180,
              reminder_intensity TEXT NOT NULL DEFAULT 'normal',
              ignored_count INTEGER NOT NULL DEFAULT 0,
              completion_rate REAL NOT NULL DEFAULT 0,
              last_reminder_at TEXT
            )
          ''');
          await db.insert('tasks', {
            'title': 'Legacy task',
            'notes': null,
            'time_label': '08:00',
            'type': 'normal',
            'slot': 'morning',
            'repeat_pattern': 'none',
            'status': 'pending',
            'created_at': DateTime(2026, 3, 25).toIso8601String(),
            'updated_at': DateTime(2026, 3, 25).toIso8601String(),
            'next_reminder_at': DateTime(2026, 3, 25, 8).toIso8601String(),
            'reminder_interval_minutes': 180,
            'reminder_intensity': 'normal',
            'ignored_count': 0,
            'completion_rate': 0.0,
            'last_reminder_at': null,
          });
          await db.execute('''
            CREATE TABLE shopping_items (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              category TEXT,
              is_completed INTEGER DEFAULT 0,
              linked_task_id TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          await db.execute('''
            CREATE TABLE task_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              task_id INTEGER NOT NULL,
              action TEXT NOT NULL,
              logged_at TEXT NOT NULL,
              metadata TEXT,
              FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE user_stats (
              id INTEGER PRIMARY KEY,
              current_streak INTEGER NOT NULL DEFAULT 0,
              longest_streak INTEGER NOT NULL DEFAULT 0,
              last_completed_date TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE achievements (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              unlocked_at TEXT NOT NULL
            )
          ''');
          await db.insert('task_logs', {
            'task_id': 1,
            'action': 'completed',
            'logged_at': DateTime(2026, 3, 25, 10).toIso8601String(),
            'metadata': null,
          });
        },
      ),
    );
    await oldDb.close();

    final upgradedDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );

    final columns = await upgradedDb.rawQuery('PRAGMA table_info(task_logs)');
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('shopping_item_id'));

    final rows = await upgradedDb.query('task_logs');
    expect(rows, hasLength(1));
    expect(rows.single['task_id'], 1);

    await upgradedDb.close();
    await File(dbPath).delete();
  });

  test('upgrades version 8 schema to include shopping sessions', () async {
    final dbPath = path.join(
      Directory.systemTemp.path,
      'taska_v8_upgrade_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final oldDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              notes TEXT,
              time_label TEXT NOT NULL,
              type TEXT NOT NULL DEFAULT 'normal',
              slot TEXT NOT NULL,
              repeat_pattern TEXT NOT NULL DEFAULT 'none',
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              next_reminder_at TEXT NOT NULL,
              reminder_interval_minutes INTEGER NOT NULL DEFAULT 180,
              reminder_intensity TEXT NOT NULL DEFAULT 'normal',
              ignored_count INTEGER NOT NULL DEFAULT 0,
              completion_rate REAL NOT NULL DEFAULT 0,
              last_reminder_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE shopping_items (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              category TEXT,
              is_completed INTEGER DEFAULT 0,
              linked_task_id TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          await db.execute('''
            CREATE TABLE shopping_sessions (
              id TEXT PRIMARY KEY,
              date DATE NOT NULL,
              title TEXT,
              status TEXT DEFAULT 'active',
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          await db.execute('''
            CREATE TABLE task_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              task_id INTEGER,
              shopping_item_id TEXT,
              action TEXT NOT NULL,
              logged_at TEXT NOT NULL,
              metadata TEXT,
              FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE user_stats (
              id INTEGER PRIMARY KEY,
              current_streak INTEGER NOT NULL DEFAULT 0,
              longest_streak INTEGER NOT NULL DEFAULT 0,
              last_completed_date TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE achievements (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              unlocked_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await oldDb.close();

    final upgradedDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );

    final columns = await upgradedDb.rawQuery(
      'PRAGMA table_info(shopping_sessions)',
    );
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('id'));
    expect(names, contains('date'));
    expect(names, contains('title'));
    expect(names, contains('status'));
    expect(names, contains('created_at'));

    await upgradedDb.close();
    await File(dbPath).delete();
  });

  test('upgrades version 9 schema to add shopping item session link', () async {
    final dbPath = path.join(
      Directory.systemTemp.path,
      'taska_v9_upgrade_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final oldDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              notes TEXT,
              time_label TEXT NOT NULL,
              type TEXT NOT NULL DEFAULT 'normal',
              slot TEXT NOT NULL,
              repeat_pattern TEXT NOT NULL DEFAULT 'none',
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              next_reminder_at TEXT NOT NULL,
              reminder_interval_minutes INTEGER NOT NULL DEFAULT 180,
              reminder_intensity TEXT NOT NULL DEFAULT 'normal',
              ignored_count INTEGER NOT NULL DEFAULT 0,
              completion_rate REAL NOT NULL DEFAULT 0,
              last_reminder_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE shopping_sessions (
              id TEXT PRIMARY KEY,
              date DATE NOT NULL,
              title TEXT,
              status TEXT DEFAULT 'active',
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          await db.execute('''
            CREATE TABLE shopping_items (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              category TEXT,
              is_completed INTEGER DEFAULT 0,
              linked_task_id TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          await db.execute('''
            CREATE TABLE task_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              task_id INTEGER,
              shopping_item_id TEXT,
              action TEXT NOT NULL,
              logged_at TEXT NOT NULL,
              metadata TEXT,
              FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE user_stats (
              id INTEGER PRIMARY KEY,
              current_streak INTEGER NOT NULL DEFAULT 0,
              longest_streak INTEGER NOT NULL DEFAULT 0,
              last_completed_date TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE achievements (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              unlocked_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await oldDb.close();

    final upgradedDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      ),
    );

    final columns = await upgradedDb.rawQuery('PRAGMA table_info(shopping_items)');
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('session_id'));

    final foreignKeys = await upgradedDb.rawQuery(
      'PRAGMA foreign_key_list(shopping_items)',
    );
    expect(
      foreignKeys.any((row) => row['table'] == 'shopping_sessions'),
      isTrue,
    );

    await upgradedDb.close();
    await File(dbPath).delete();
  });
}
