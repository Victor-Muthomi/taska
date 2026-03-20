import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taska/core/notifications/notification_channels.dart';
import 'package:taska/core/notifications/notification_providers.dart';
import 'package:taska/core/notifications/notification_service.dart';
import 'package:taska/core/settings/app_settings.dart';
import 'package:taska/core/settings/app_settings_providers.dart';
import 'package:taska/core/settings/app_settings_storage.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';
import 'package:taska/features/tasks/domain/entities/task_log.dart';
import 'package:taska/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:taska/features/tasks/presentation/pages/all_tasks_page.dart';
import 'package:taska/features/tasks/presentation/providers/tasks_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            final dir = await Directory.systemTemp.createTemp(
              'taska_all_tasks_docs',
            );
            return dir.path;
          }
          return null;
        });
  });

  testWidgets('searches and sorts all tasks', (tester) async {
    final now = DateTime(2026, 3, 20, 10);
    final repository = _FakeTasksRepository(
      tasks: [
        _task(
          id: 1,
          title: 'Zebra cleanup',
          notes: 'Kitchen sink',
          updatedAt: now.subtract(const Duration(hours: 3)),
          nextReminderAt: now.add(const Duration(hours: 4)),
        ),
        _task(
          id: 2,
          title: 'Alpha review',
          notes: 'Meeting prep',
          updatedAt: now.subtract(const Duration(hours: 1)),
          nextReminderAt: now.add(const Duration(hours: 1)),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(repository),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
          appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
        ],
        child: const MaterialApp(home: AllTasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zebra cleanup'), findsOneWidget);
    expect(find.text('Alpha review'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kitchen');
    await tester.pumpAndSettle();
    expect(find.text('Zebra cleanup'), findsOneWidget);
    expect(find.text('Alpha review'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title').last);
    await tester.pumpAndSettle();

    final sortedTitles = tester.widgetList<Text>(find.byType(Text)).
        where((text) => text.data == 'Alpha review' || text.data == 'Zebra cleanup')
        .map((text) => text.data)
        .toList();

    expect(sortedTitles.first, 'Alpha review');
  });
}

class _FakeTasksRepository implements TasksRepository {
  _FakeTasksRepository({List<Task>? tasks, List<TaskLog>? logs})
    : tasks = tasks ?? [],
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
  Future<void> save(AppSettings settings) async {}

  @override
  Future<AppSettings> load() async => AppSettings.defaults();
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
  required String notes,
  required DateTime updatedAt,
  required DateTime nextReminderAt,
}) {
  return Task(
    id: id,
    title: title,
    notes: notes,
    timeLabel: '08:00',
    slot: TaskSlot.morning,
    repeat: TaskRepeat.none,
    status: TaskReminderStatus.pending,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    nextReminderAt: nextReminderAt,
    reminderIntervalMinutes: 180,
    reminderIntensity: TaskReminderIntensity.normal,
    ignoredCount: 0,
    completionRate: 0,
  );
}