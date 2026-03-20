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
}
