import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taska/core/database/app_database.dart';
import 'package:taska/features/tasks/data/datasources/tasks_local_data_source.dart';
import 'package:taska/features/tasks/data/repositories/tasks_repository_impl.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';
import 'package:taska/features/tasks/domain/entities/task_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late TasksRepositoryImpl repository;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            final dir = await Directory.systemTemp.createTemp(
              'taska_repo_docs',
            );
            return dir.path;
          }
          return null;
        });
    repository = TasksRepositoryImpl(
      localDataSource: TasksLocalDataSource(
        databaseHelper: AppDatabase.instance,
      ),
    );
  });

  setUp(() async {
    final db = await AppDatabase.instance.database;
    await db.delete('task_logs');
    await db.delete('tasks');
  });

  test('repository persists task status changes and log actions', () async {
    final created = await repository.createTask(_task(title: 'Call mom'));

    await repository.updateTaskStatus(
      taskId: created.id!,
      status: TaskReminderStatus.ignored,
    );
    await repository.logTaskAction(
      TaskLog(
        taskId: created.id!,
        action: 'ignored',
        loggedAt: DateTime(2026, 3, 20, 10),
      ),
    );

    final tasks = await repository.getTasks();
    final logs = await repository.getTaskLogs(created.id!);

    expect(tasks.single.status, TaskReminderStatus.ignored);
    expect(logs.single.action, 'ignored');
  });

  test('repository updates and deletes full tasks', () async {
    final created = await repository.createTask(_task(title: 'Plan trip'));

    await repository.updateTask(
      created.copyWith(
        title: 'Plan trip budget',
        slot: TaskSlot.evening,
        repeat: TaskRepeat.weekly,
      ),
    );

    final updated = await repository.getTasks();
    expect(updated.single.title, 'Plan trip budget');
    expect(updated.single.slot, TaskSlot.evening);
    expect(updated.single.repeat, TaskRepeat.weekly);

    await repository.deleteTask(created.id!);
    expect(await repository.getTasks(), isEmpty);
  });
}

Task _task({required String title}) {
  return Task(
    title: title,
    notes: null,
    timeLabel: '08:00',
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
