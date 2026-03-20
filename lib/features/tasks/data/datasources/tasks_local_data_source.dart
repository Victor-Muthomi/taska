import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../models/task_log_model.dart';
import '../models/task_model.dart';

class TasksLocalDataSource {
  TasksLocalDataSource({required AppDatabase databaseHelper})
    : _databaseHelper = databaseHelper;

  final AppDatabase _databaseHelper;

  Future<List<TaskModel>> getTasks() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('tasks', orderBy: 'created_at DESC');
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<List<TaskLogModel>> getTaskLogs(int taskId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'task_logs',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'logged_at DESC',
    );
    return rows.map(TaskLogModel.fromMap).toList();
  }

  Future<List<TaskLogModel>> getAllTaskLogs() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('task_logs', orderBy: 'logged_at DESC');
    return rows.map(TaskLogModel.fromMap).toList();
  }

  Future<TaskModel> createTask(TaskModel task) async {
    final db = await _databaseHelper.database;
    final taskId = await db.insert(
      'tasks',
      task.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return task.copyWith(id: taskId);
  }

  Future<void> updateTask(TaskModel task) async {
    final db = await _databaseHelper.database;
    await db.update(
      'tasks',
      task.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> updateTaskStatus({
    required int taskId,
    required String status,
    required DateTime updatedAt,
  }) async {
    final db = await _databaseHelper.database;
    await db.update(
      'tasks',
      {'status': status, 'updated_at': updatedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> deleteTask(int taskId) async {
    final db = await _databaseHelper.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  Future<void> logTaskAction(TaskLogModel log) async {
    final db = await _databaseHelper.database;
    await db.insert('task_logs', log.toMap()..remove('id'));
  }
}
