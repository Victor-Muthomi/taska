import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taska/core/database/app_database.dart';
import 'package:taska/features/tasks/data/datasources/tasks_local_data_source.dart';
import 'package:taska/features/tasks/data/models/task_log_model.dart';
import 'package:taska/features/tasks/data/models/task_model.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late TasksLocalDataSource dataSource;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            final dir = await Directory.systemTemp.createTemp(
              'taska_test_docs',
            );
            return dir.path;
          }
          return null;
        });
    dataSource = TasksLocalDataSource(databaseHelper: AppDatabase.instance);
  });

  setUp(() async {
    final db = await AppDatabase.instance.database;
    await db.delete('task_logs');
    await db.delete('tasks');
  });

  test('creates, updates, fetches, logs, and deletes tasks locally', () async {
    final created = await dataSource.createTask(_taskModel(title: 'Hydrate'));

    expect(created.id, isNotNull);

    await dataSource.logTaskAction(
      TaskLogModel(
        taskId: created.id!,
        action: 'created',
        loggedAt: DateTime(2026, 3, 20, 7),
      ),
    );

    final afterCreate = await dataSource.getTasks();
    expect(afterCreate, hasLength(1));
    expect(afterCreate.single.title, 'Hydrate');

    await dataSource.updateTask(
      created.copyWith(
        title: 'Hydrate well',
        status: TaskReminderStatus.snoozed,
      ),
    );
    await dataSource.updateTaskStatus(
      taskId: created.id!,
      status: TaskReminderStatus.completed.name,
      updatedAt: DateTime(2026, 3, 20, 9),
    );

    final updated = await dataSource.getTasks();
    expect(updated.single.title, 'Hydrate well');
    expect(updated.single.status, TaskReminderStatus.completed);

    final logs = await dataSource.getTaskLogs(created.id!);
    final allLogs = await dataSource.getAllTaskLogs();
    expect(logs, hasLength(1));
    expect(allLogs.single.action, 'created');

    await dataSource.deleteTask(created.id!);

    expect(await dataSource.getTasks(), isEmpty);
    expect(await dataSource.getAllTaskLogs(), isEmpty);
  });
}

TaskModel _taskModel({required String title}) {
  return TaskModel(
    title: title,
    notes: 'notes',
    timeLabel: '08:00',
    type: TaskType.normal,
    slot: TaskSlot.morning,
    repeat: TaskRepeat.none,
    status: TaskReminderStatus.pending,
    createdAt: DateTime(2026, 3, 20, 8),
    updatedAt: DateTime(2026, 3, 20, 8),
    nextReminderAt: DateTime(2026, 3, 20, 8),
    reminderIntervalMinutes: 180,
    reminderIntensity: TaskReminderIntensity.normal,
    ignoredCount: 0,
    completionRate: 0,
  );
}
