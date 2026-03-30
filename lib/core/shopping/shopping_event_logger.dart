import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/shopping/domain/entities/shopping_item.dart';
import '../../features/shopping/domain/entities/shopping_session.dart';
import '../database/app_database.dart';

abstract class ShoppingEventLogger {
  Future<void> logItemAdded(ShoppingItem item);
  Future<void> logSessionCreated(ShoppingSession session);
  Future<void> logItemUpdated(ShoppingItem item);
  Future<void> logItemCompleted(ShoppingItem item);
}

class ShoppingEventLoggerImpl implements ShoppingEventLogger {
  ShoppingEventLoggerImpl({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  @override
  Future<void> logSessionCreated(ShoppingSession session) async {
    final db = await _database.database;
    await db.insert(
      'task_logs',
      {
        'task_id': null,
        'shopping_item_id': null,
        'action': 'session_created',
        'logged_at': DateTime.now().toIso8601String(),
        'metadata': jsonEncode({
          'session_id': session.id,
          'title': session.title,
          'date': session.date.toIso8601String(),
        }),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> logItemAdded(ShoppingItem item) async {
    await _insertEvent(action: 'item_added', item: item);
  }

  @override
  Future<void> logItemUpdated(ShoppingItem item) async {
    await _insertEvent(action: 'item_updated', item: item);
  }

  @override
  Future<void> logItemCompleted(ShoppingItem item) async {
    await _insertEvent(action: 'item_completed', item: item);
  }

  Future<void> _insertEvent({
    required String action,
    required ShoppingItem item,
  }) async {
    final db = await _database.database;
    await db.insert(
      'task_logs',
      {
        'task_id': _taskIdFromLinkedTask(item.linkedTaskId),
        'shopping_item_id': item.id,
        'action': action,
        'logged_at': DateTime.now().toIso8601String(),
        'metadata': null,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  int? _taskIdFromLinkedTask(String? linkedTaskId) {
    if (linkedTaskId == null) {
      return null;
    }
    return int.tryParse(linkedTaskId);
  }
}