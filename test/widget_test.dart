import 'package:flutter/material.dart';
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
import 'package:taska/features/tasks/presentation/pages/tasks_page.dart';
import 'package:taska/features/tasks/presentation/providers/tasks_providers.dart';

void main() {
  testWidgets('App shows project shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(_FakeTasksRepository()),
          appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Smart Schedule Manager'), findsOneWidget);
    expect(
      find.text('Stop missing time windows, not just exact clock times.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard add task form validates and saves', (
    WidgetTester tester,
  ) async {
    final repository = _FakeTasksRepository();
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

    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);

    final saveButton = find.widgetWithText(FilledButton, 'Save Task');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Add a short task title.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Morning review');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    final tasks = await repository.getTasks();
    expect(tasks.map((task) => task.title), contains('Morning review'));
  });

  testWidgets('dashboard add task form shows editable date field', (
    WidgetTester tester,
  ) async {
    final repository = _FakeTasksRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(repository),
          appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Consumer(
                builder: (context, ref, _) {
                  return FilledButton(
                    onPressed: () {
                      TasksPage.showTaskFormSheet(
                        context,
                        ref: ref,
                        scheduledFor: DateTime(2026, 3, 24),
                      );
                    },
                    child: const Text('Open form'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('2026-03-24'), findsOneWidget);
  });

  testWidgets('shell navigates to stats and settings and toggles dark mode', (
    WidgetTester tester,
  ) async {
    final repository = _FakeTasksRepository(
      tasks: [
        _demoTask(
          id: 1,
          title: 'Evening stretch',
          slot: TaskSlot.evening,
          status: TaskReminderStatus.completed,
        ),
      ],
      logs: [
        TaskLog(
          taskId: 1,
          action: 'completed',
          loggedAt: DateTime(2026, 3, 20, 20),
        ),
      ],
    );
    final settingsStorage = _FakeSettingsStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(repository),
          appSettingsStorageProvider.overrideWithValue(settingsStorage),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stats').last);
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Default snooze duration'), findsOneWidget);

    final appBefore = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appBefore.themeMode, ThemeMode.light);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final appAfter = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appAfter.themeMode, ThemeMode.dark);
    expect(settingsStorage.savedSettings?.themeMode, ThemeMode.dark);
  });
}

class _FakeTasksRepository implements TasksRepository {
  _FakeTasksRepository({List<Task>? tasks, List<TaskLog>? logs})
    : _tasks = tasks ?? [],
      _logs = logs ?? [];

  final List<Task> _tasks;
  final List<TaskLog> _logs;

  @override
  Future<Task> createTask(Task task) async {
    final created = task.copyWith(id: _tasks.length + 1);
    _tasks.insert(0, created);
    return created;
  }

  @override
  Future<void> deleteTask(int taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
    _logs.removeWhere((log) => log.taskId == taskId);
  }

  @override
  Future<List<TaskLog>> getAllTaskLogs() async => List<TaskLog>.from(_logs);

  @override
  Future<List<Task>> getTasks() async => List<Task>.from(_tasks);

  @override
  Future<List<TaskLog>> getTaskLogs(int taskId) async {
    return _logs.where((log) => log.taskId == taskId).toList();
  }

  @override
  Future<void> updateTask(Task task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) {
      _tasks[index] = task;
    }
  }

  @override
  Future<void> updateTaskStatus({
    required int taskId,
    required TaskReminderStatus status,
  }) async {
    final index = _tasks.indexWhere((item) => item.id == taskId);
    if (index >= 0) {
      _tasks[index] = _tasks[index].copyWith(status: status);
    }
  }

  @override
  Future<void> logTaskAction(TaskLog log) async {
    _logs.insert(0, log);
  }
}

class _FakeSettingsStorage extends AppSettingsStorage {
  AppSettings? savedSettings;

  @override
  Future<AppSettings> load() async => AppSettings.defaults();

  @override
  Future<void> save(AppSettings settings) async {
    savedSettings = settings;
  }
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

Task _demoTask({
  required int id,
  required String title,
  required TaskSlot slot,
  required TaskReminderStatus status,
}) {
  return Task(
    id: id,
    title: title,
    notes: null,
    timeLabel: '08:00',
    slot: slot,
    repeat: TaskRepeat.none,
    status: status,
    createdAt: DateTime(2026, 3, 20, 8),
    updatedAt: DateTime(2026, 3, 20, 8),
    nextReminderAt: DateTime(2026, 3, 20, 8),
    reminderIntervalMinutes: 180,
    reminderIntensity: TaskReminderIntensity.normal,
    ignoredCount: 0,
    completionRate: 0,
  );
}
