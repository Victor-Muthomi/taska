import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../../features/tasks/domain/entities/task.dart';
import '../../features/tasks/domain/entities/task_log.dart';

class ExportService {
  const ExportService({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<String> exportToJson({
    required List<Task> tasks,
    required List<TaskLog> logs,
  }) async {
    final exportDirectory = await _exportDirectory();
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    final fileName =
        'taska_export_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(path.join(exportDirectory.path, fileName));
    final payload = {
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': tasks.map(_taskToMap).toList(),
      'taskLogs': logs.map(_logToMap).toList(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    return file.path;
  }

  Future<String?> latestBackupPath() async {
    final exportDirectory = await _exportDirectory();
    if (!await exportDirectory.exists()) {
      return null;
    }

    final files =
        exportDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );

    return files.isEmpty ? null : files.first.path;
  }

  Future<void> importFromJsonFile(String filePath) async {
    final source = await File(filePath).readAsString();
    final payload = jsonDecode(source) as Map<String, dynamic>;

    final tasks = (payload['tasks'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final logs = (payload['taskLogs'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('task_logs');
      await txn.delete('tasks');

      for (final task in tasks) {
        await txn.insert('tasks', _taskMapFromJson(task));
      }

      for (final log in logs) {
        await txn.insert('task_logs', _logMapFromJson(log));
      }
    });
  }

  Future<String?> restoreLatestBackup() async {
    final latestPath = await latestBackupPath();
    if (latestPath == null) {
      return null;
    }

    await importFromJsonFile(latestPath);
    return latestPath;
  }

  Map<String, Object?> _taskToMap(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'notes': task.notes,
      'timeLabel': task.timeLabel,
      'type': task.type.name,
      'slot': task.slot.name,
      'repeat': task.repeat.name,
      'status': task.status.name,
      'createdAt': task.createdAt.toIso8601String(),
      'updatedAt': task.updatedAt.toIso8601String(),
      'nextReminderAt': task.nextReminderAt.toIso8601String(),
      'reminderIntervalMinutes': task.reminderIntervalMinutes,
      'reminderIntensity': task.reminderIntensity.name,
      'ignoredCount': task.ignoredCount,
      'completionRate': task.completionRate,
      'lastReminderAt': task.lastReminderAt?.toIso8601String(),
    };
  }

  Map<String, Object?> _logToMap(TaskLog log) {
    return {
      'id': log.id,
      'taskId': log.taskId,
      'action': log.action,
      'loggedAt': log.loggedAt.toIso8601String(),
      'metadata': log.metadata,
    };
  }

  Map<String, Object?> _taskMapFromJson(Map<String, dynamic> task) {
    return {
      'id': task['id'] as int?,
      'title': task['title'] as String,
      'notes': task['notes'] as String?,
      'time_label': task['timeLabel'] as String,
      'type': (task['type'] as String?) ?? 'normal',
      'slot': task['slot'] as String,
      'repeat_pattern': task['repeat'] as String,
      'status': task['status'] as String,
      'created_at': task['createdAt'] as String,
      'updated_at': task['updatedAt'] as String,
      'next_reminder_at': task['nextReminderAt'] as String,
      'reminder_interval_minutes': task['reminderIntervalMinutes'] as int,
      'reminder_intensity': task['reminderIntensity'] as String,
      'ignored_count': task['ignoredCount'] as int,
      'completion_rate': (task['completionRate'] as num).toDouble(),
      'last_reminder_at': task['lastReminderAt'] as String?,
    };
  }

  Map<String, Object?> _logMapFromJson(Map<String, dynamic> log) {
    return {
      'id': log['id'] as int?,
      'task_id': log['taskId'] as int,
      'action': log['action'] as String,
      'logged_at': log['loggedAt'] as String,
      'metadata': log['metadata'] as String?,
    };
  }

  Future<Directory> _exportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory(path.join(directory.path, 'exports'));
  }
}
