import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../models/shopping_session_model.dart';
import '../models/shopping_item_model.dart';

class ShoppingLocalDataSource {
  ShoppingLocalDataSource({required AppDatabase databaseHelper})
    : _databaseHelper = databaseHelper;

  final AppDatabase _databaseHelper;

  Future<ShoppingSessionModel> createSession(
    ShoppingSessionModel session,
  ) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'shopping_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return session;
  }

  Future<List<ShoppingSessionModel>> getSessions() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('shopping_sessions', orderBy: 'date DESC');
    return rows.map(ShoppingSessionModel.fromMap).toList();
  }

  Future<ShoppingSessionModel?> getSessionById(String id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'shopping_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ShoppingSessionModel.fromMap(rows.first);
  }

  Future<void> updateSession(ShoppingSessionModel session) async {
    final db = await _databaseHelper.database;
    await db.update(
      'shopping_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> countItemsBySessionId(String sessionId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM shopping_items WHERE session_id = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> deleteSession(String id) async {
    final db = await _databaseHelper.database;
    await db.delete('shopping_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<ShoppingItemModel?> getItemById(String itemId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'shopping_items',
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ShoppingItemModel.fromMap(rows.first);
  }

  Future<List<ShoppingItemModel>> getItems() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('shopping_items', orderBy: 'created_at DESC');
    return rows.map(ShoppingItemModel.fromMap).toList();
  }

  Future<List<ShoppingItemModel>> getItemsBySession(String sessionId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'shopping_items',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ShoppingItemModel.fromMap).toList();
  }

  Future<List<ShoppingItemModel>> getItemsByTask(String taskId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'shopping_items',
      where: 'linked_task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ShoppingItemModel.fromMap).toList();
  }

  Future<ShoppingItemModel> addItem(ShoppingItemModel item) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'shopping_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return item;
  }

  Future<ShoppingItemModel> updateItem(ShoppingItemModel item) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'shopping_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return item;
  }

  Future<void> updateItemStatus({
    required String itemId,
    required bool isCompleted,
  }) async {
    final db = await _databaseHelper.database;
    await db.update(
      'shopping_items',
      {'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteItem(String itemId) async {
    final db = await _databaseHelper.database;
    await db.delete('shopping_items', where: 'id = ?', whereArgs: [itemId]);
  }
}