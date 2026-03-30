import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taska/core/notifications/notification_channels.dart';
import 'package:taska/core/notifications/notification_providers.dart';
import 'package:taska/core/notifications/notification_service.dart';
import 'package:taska/core/notifications/notification_logic.dart';
import 'package:taska/core/rewards/models/achievement.dart';
import 'package:taska/core/rewards/models/user_stats.dart';
import 'package:taska/core/rewards/repository/reward_repository.dart';
import 'package:taska/core/rewards/reward_providers.dart';
import 'package:taska/core/rewards/services/reward_engine.dart';
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
              'taska_provider_docs',
            );
            return dir.path;
          }
          return null;
        });
  });

  test('updateTaskDetails persists edits and recalculates reminders', () async {
    final before = DateTime.now();
    final repository = _FakeTasksRepository(
      tasks: [
        Task(
          id: 1,
          title: 'Morning review',
          notes: 'old notes',
          timeLabel: '08:00',
          slot: TaskSlot.morning,
          repeat: TaskRepeat.none,
          status: TaskReminderStatus.pending,
          createdAt: before.subtract(const Duration(days: 2)),
          updatedAt: before.subtract(const Duration(days: 2)),
          nextReminderAt: before.add(const Duration(hours: 2)),
          reminderIntervalMinutes: 180,
          reminderIntensity: TaskReminderIntensity.normal,
          ignoredCount: 0,
          completionRate: 0,
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        tasksRepositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
        rewardEngineProvider.overrideWithValue(_FakeRewardEngine()),
        appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
        initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);

    await container
        .read(tasksControllerProvider.notifier)
        .updateTaskDetails(
          task: repository.tasks.single,
          title: 'Updated review',
          notes: 'fresh notes',
          timeLabel: '09:30',
          type: TaskType.normal,
          slot: TaskSlot.afternoon,
          repeat: TaskRepeat.daily,
        );

    final updated = repository.tasks.single;
    expect(updated.title, 'Updated review');
    expect(updated.notes, 'fresh notes');
    expect(updated.slot, TaskSlot.afternoon);
    expect(updated.repeat, TaskRepeat.daily);
    expect(updated.createdAt, before.subtract(const Duration(days: 2)));
    expect(updated.updatedAt.isAfter(before), isTrue);
    expect(updated.nextReminderAt.isAfter(before), isTrue);
    expect(updated.id, 1);
  });

  test('addTask keeps the created task on the selected calendar day', () async {
    final repository = _FakeTasksRepository();
    final now = DateTime.now();
    final scheduledFor = DateTime(now.year, now.month, now.day + 1);

    final container = ProviderContainer(
      overrides: [
        tasksRepositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
        rewardEngineProvider.overrideWithValue(_FakeRewardEngine()),
        appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
        initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);
    await container
        .read(tasksControllerProvider.notifier)
        .addTask(
          title: 'Calendar task',
          notes: 'from calendar',
          timeLabel: '23:00',
          type: TaskType.normal,
          slot: TaskSlot.evening,
          repeat: TaskRepeat.none,
          scheduledFor: scheduledFor,
        );

    expect(repository.tasks, hasLength(1));
    final created = repository.tasks.single;
    expect(created.title, 'Calendar task');
    expect(created.nextReminderAt.year, scheduledFor.year);
    expect(created.nextReminderAt.month, scheduledFor.month);
    expect(created.nextReminderAt.day, scheduledFor.day);
  });

  test('toggleSnoozeTask snoozes a pending task', () async {
    final before = DateTime.now();
    final repository = _FakeTasksRepository(
      tasks: [
        Task(
          id: 1,
          title: 'Focus block',
          notes: null,
          timeLabel: '10:00',
          slot: TaskSlot.morning,
          repeat: TaskRepeat.none,
          status: TaskReminderStatus.pending,
          createdAt: before,
          updatedAt: before,
          nextReminderAt: before,
          reminderIntervalMinutes: 120,
          reminderIntensity: TaskReminderIntensity.normal,
          ignoredCount: 0,
          completionRate: 0,
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        tasksRepositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
        rewardEngineProvider.overrideWithValue(_FakeRewardEngine()),
        appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
        initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);

    await container
        .read(tasksControllerProvider.notifier)
        .toggleSnoozeTask(repository.tasks.single);

    final updated = repository.tasks.single;
    expect(updated.status, TaskReminderStatus.snoozed);
    expect(updated.nextReminderAt.isAfter(before), isTrue);
  });

  test('toggleSnoozeTask unsnoozes a snoozed task', () async {
    final before = DateTime.now();
    final repository = _FakeTasksRepository(
      tasks: [
        Task(
          id: 1,
          title: 'Focus block',
          notes: null,
          timeLabel: '10:00',
          slot: TaskSlot.morning,
          repeat: TaskRepeat.none,
          status: TaskReminderStatus.snoozed,
          createdAt: before,
          updatedAt: before,
          nextReminderAt: before.add(const Duration(minutes: 10)),
          reminderIntervalMinutes: 120,
          reminderIntensity: TaskReminderIntensity.normal,
          ignoredCount: 0,
          completionRate: 0,
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        tasksRepositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
        rewardEngineProvider.overrideWithValue(_FakeRewardEngine()),
        appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
        initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);

    await container
        .read(tasksControllerProvider.notifier)
        .toggleSnoozeTask(repository.tasks.single);

    final updated = repository.tasks.single;
    expect(updated.status, TaskReminderStatus.pending);
    expect(updated.nextReminderAt.isAfter(before), isTrue);
  });

  test('handleNotificationEvent snoozes and schedules once', () async {
    final before = DateTime.now();
    final repository = _FakeTasksRepository(
      tasks: [
        Task(
          id: 1,
          title: 'Focus block',
          notes: null,
          timeLabel: '10:00',
          slot: TaskSlot.morning,
          repeat: TaskRepeat.none,
          status: TaskReminderStatus.pending,
          createdAt: before,
          updatedAt: before,
          nextReminderAt: before,
          reminderIntervalMinutes: 120,
          reminderIntensity: TaskReminderIntensity.normal,
          ignoredCount: 0,
          completionRate: 0,
        ),
      ],
    );
    final notificationService = _FakeNotificationService();

    final container = ProviderContainer(
      overrides: [
        tasksRepositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(notificationService),
        rewardEngineProvider.overrideWithValue(_FakeRewardEngine()),
        appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
        initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);
    notificationService.scheduleCallCount = 0;
    notificationService.cancelCallCount = 0;

    await container
        .read(tasksControllerProvider.notifier)
        .handleNotificationEvent(
          const NotificationEvent(
            taskId: 1,
            type: NotificationEventType.snoozed,
          ),
        );

    final updated = repository.tasks.single;
    expect(updated.status, TaskReminderStatus.snoozed);
    expect(updated.nextReminderAt.isAfter(before), isTrue);
    expect(notificationService.scheduleCallCount, 1);
    expect(notificationService.cancelCallCount, 0);
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
  Future<AppSettings> load() async => AppSettings.defaults();

  @override
  Future<void> save(AppSettings settings) async {}
}

class _FakeNotificationService extends NotificationService {
  int scheduleCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleTaskNotification({
    required Task task,
    required AppSettings settings,
    ReminderPriority? priority,
  }) async {
    scheduleCallCount += 1;
  }

  @override
  Future<void> cancelTaskNotification(int taskId) async {
    cancelCallCount += 1;
  }
}

class _FakeRewardEngine extends RewardEngine {
  _FakeRewardEngine()
    : super(repository: _FakeRewardRepository());

  @override
  Future<void> refreshFromLogs({DateTime? today}) async {}

  @override
  Future<void> evaluateAchievements(TaskLog log) async {}

  @override
  Future<void> unlockAchievement(String id) async {}

  @override
  Future<List<Achievement>> getUnlockedAchievements() async => const [];

  @override
  Future<UserStats> getUserStats() async => UserStats.initial();
}

class _FakeRewardRepository implements RewardRepository {
  @override
  Future<void> saveUserStats(UserStats stats) async {}

  @override
  Future<List<TaskLog>> getAllTaskLogs() async => const [];

  @override
  Future<List<TaskLog>> getTaskLogsForTask(int taskId) async => const [];

  @override
  Future<List<Achievement>> getUnlockedAchievements() async => const [];

  @override
  Future<void> unlockAchievement(Achievement achievement) async {}

  @override
  Future<UserStats> getUserStats() async => UserStats.initial();
}
