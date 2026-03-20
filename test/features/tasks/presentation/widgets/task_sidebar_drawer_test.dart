import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taska/app/app.dart';
import 'package:taska/core/notifications/notification_channels.dart';
import 'package:taska/core/notifications/notification_providers.dart';
import 'package:taska/core/notifications/notification_service.dart';
import 'package:taska/core/settings/app_settings.dart';
import 'package:taska/core/settings/app_settings_providers.dart';
import 'package:taska/core/settings/app_settings_storage.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';
import 'package:taska/features/tasks/domain/entities/task_log.dart';
import 'package:taska/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:taska/features/tasks/presentation/providers/tasks_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            final dir = await Directory.systemTemp.createTemp(
              'taska_sidebar_docs',
            );
            return dir.path;
          }
          return null;
        });
  });

  testWidgets('sidebar opens calendar screen and data actions remain available', (
    tester,
  ) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day, 23);
    final tomorrowDate = todayDate.add(const Duration(days: 1));

    final repository = _FakeTasksRepository(
      tasks: [
        _task(
          id: 1,
          title: 'Today task',
          nextReminderAt: todayDate,
        ),
        _task(
          id: 2,
          title: 'Tomorrow task',
          nextReminderAt: tomorrowDate,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(repository),
          appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Sidebar'), findsOneWidget);
    expect(find.text('Export JSON'), findsOneWidget);

    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
  });
}

class _FakeTasksRepository implements TasksRepository {
  _FakeTasksRepository({List<Task>? tasks, List<Task>? taskList, List<TaskLog>? logs})
    : tasks = tasks ?? taskList ?? [],
      logs = logs ?? [];

  final List<Task> tasks;
  final List<TaskLog> logs;

  @override
  Future<Task> createTask(Task task) async {
    final created = task.copyWith(id: tasks.length + 1);
    tasks.insert(0, created);
    return created;
  }

  @override
  Future<void> deleteTask(int taskId) async {
    tasks.removeWhere((task) => task.id == taskId);
    logs.removeWhere((log) => log.taskId == taskId);
  }

  @override
  Future<List<TaskLog>> getAllTaskLogs() async => List<TaskLog>.from(logs);

  @override
  Future<List<Task>> getTasks() async => List<Task>.from(tasks);

  @override
  Future<List<TaskLog>> getTaskLogs(int taskId) async {
    return logs.where((log) => log.taskId == taskId).toList();
  }

  @override
  Future<void> updateTask(Task task) async {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) {
      tasks[index] = task;
    }
  }

  @override
  Future<void> updateTaskStatus({
    required int taskId,
    required TaskReminderStatus status,
  }) async {
    final index = tasks.indexWhere((item) => item.id == taskId);
    if (index >= 0) {
      tasks[index] = tasks[index].copyWith(status: status);
    }
  }

  @override
  Future<void> logTaskAction(TaskLog log) async {
    logs.insert(0, log);
  }
}

class _FakeSettingsStorage extends AppSettingsStorage {
  @override
  Future<AppSettings> load() async => AppSettings.defaults();

  @override
  Future<void> save(AppSettings settings) async {}
}

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleTaskNotification({
    required Task task,
    required AppSettings settings,
    ReminderPriority? priority,
  }) async {}

  @override
  Future<void> cancelTaskNotification(int taskId) async {}
}

Task _task({
  required int id,
  required String title,
  required DateTime nextReminderAt,
}) {
  return Task(
    id: id,
    title: title,
    notes: null,
    timeLabel: '08:00',
    slot: TaskSlot.morning,
    repeat: TaskRepeat.none,
    status: TaskReminderStatus.pending,
    createdAt: nextReminderAt,
    updatedAt: nextReminderAt,
    nextReminderAt: nextReminderAt,
    reminderIntervalMinutes: 180,
    reminderIntensity: TaskReminderIntensity.normal,
    ignoredCount: 0,
    completionRate: 0,
  );
}