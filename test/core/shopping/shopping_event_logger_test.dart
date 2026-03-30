import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taska/core/database/app_database.dart';
import 'package:taska/core/shopping/shopping_event_logger.dart';
import 'package:taska/features/shopping/domain/entities/shopping_item.dart';
import 'package:taska/features/shopping/domain/entities/shopping_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late ShoppingEventLoggerImpl logger;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            final dir = await Directory.systemTemp.createTemp(
              'taska_shopping_event_docs',
            );
            return dir.path;
          }
          return null;
        });
    logger = ShoppingEventLoggerImpl(database: AppDatabase.instance);
  });

  setUp(() async {
    final db = await AppDatabase.instance.database;
    await db.delete('task_logs');
    await db.delete('tasks');
  });

  test('writes shopping item events into task_logs', () async {
    final db = await AppDatabase.instance.database;
    await db.insert('tasks', {
      'id': 7,
      'title': 'Groceries',
      'notes': null,
      'time_label': '08:00',
      'type': 'shopping',
      'slot': 'morning',
      'repeat_pattern': 'none',
      'status': 'pending',
      'created_at': DateTime(2026, 3, 25, 10).toIso8601String(),
      'updated_at': DateTime(2026, 3, 25, 10).toIso8601String(),
      'next_reminder_at': DateTime(2026, 3, 25, 10).toIso8601String(),
      'reminder_interval_minutes': 180,
      'reminder_intensity': 'normal',
      'ignored_count': 0,
      'completion_rate': 0,
      'last_reminder_at': null,
    });

    final item = ShoppingItem(
      id: 'item-1',
      name: 'Milk',
      category: 'Groceries',
      isCompleted: false,
      linkedTaskId: '7',
      createdAt: DateTime(2026, 3, 25, 10),
    );

    await logger.logItemAdded(item);
    await logger.logItemCompleted(item.copyWith(isCompleted: true));

    final rows = await db.query('task_logs', orderBy: 'logged_at ASC');

    expect(rows, hasLength(2));
    expect(rows.first['action'], 'item_added');
    expect(rows.first['shopping_item_id'], 'item-1');
    expect(rows.last['action'], 'item_completed');
    expect(rows.last['shopping_item_id'], 'item-1');
    expect(rows.last['task_id'], 7);
  });

  test('writes session and item update events into task_logs', () async {
    final db = await AppDatabase.instance.database;
    final session = ShoppingSession(
      id: 'session-1',
      date: DateTime(2026, 3, 25),
      title: 'Groceries',
      status: ShoppingSessionStatus.active,
      createdAt: DateTime(2026, 3, 25, 9),
    );
    final item = ShoppingItem(
      id: 'item-2',
      name: 'Bread',
      category: 'Groceries',
      isCompleted: false,
      sessionId: 'session-1',
      createdAt: DateTime(2026, 3, 25, 10),
    );

    await logger.logSessionCreated(session);
    await logger.logItemUpdated(item);

    final rows = await db.query('task_logs', orderBy: 'logged_at ASC');

    expect(rows, hasLength(2));
    expect(rows[0]['action'], 'session_created');
    expect(rows[1]['action'], 'item_updated');
    expect(rows[1]['shopping_item_id'], 'item-2');
  });
}