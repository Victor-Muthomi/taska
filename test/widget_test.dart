import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taska/app/app.dart';
import 'package:taska/core/analytics/behavior_analytics.dart';
import 'package:taska/core/analytics/behavior_analytics_providers.dart';
import 'package:taska/core/notifications/notification_channels.dart';
import 'package:taska/core/notifications/notification_providers.dart';
import 'package:taska/core/notifications/notification_service.dart';
import 'package:taska/core/rewards/models/achievement.dart';
import 'package:taska/core/rewards/models/user_stats.dart';
import 'package:taska/core/rewards/repository/reward_repository.dart';
import 'package:taska/core/rewards/reward_providers.dart';
import 'package:taska/core/rewards/reward_state_providers.dart';
import 'package:taska/core/rewards/services/reward_engine.dart';
import 'package:taska/core/settings/app_settings.dart';
import 'package:taska/core/settings/app_settings_providers.dart';
import 'package:taska/core/settings/app_settings_storage.dart';
import 'package:taska/features/shopping/domain/entities/shopping_item.dart';
import 'package:taska/features/shopping/presentation/providers/shopping_providers.dart';
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
          rewardEngineProvider.overrideWithValue(_FakeRewardEngine()),
          rewardUserStatsProvider.overrideWith((ref) async {
            return UserStats(
              id: 1,
              currentStreak: 3,
              longestStreak: 5,
              lastCompletedDate: DateTime(2026, 3, 20),
            );
          }),
          rewardAchievementsProvider.overrideWith((ref) async {
            return [
              Achievement(
                id: 'consistency_starter',
                title: 'Consistency Starter',
                description:
                    'Complete at least one task for 3 consecutive days.',
                unlockedAt: DateTime(2026, 3, 20),
              ),
            ];
          }),
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
          rewardEngineProvider.overrideWithValue(_FakeRewardEngine()),
          rewardUserStatsProvider.overrideWith((ref) async {
            return UserStats(
              id: 1,
              currentStreak: 3,
              longestStreak: 5,
              lastCompletedDate: DateTime(2026, 3, 20),
            );
          }),
          rewardAchievementsProvider.overrideWith((ref) async {
            return [
              Achievement(
                id: 'consistency_starter',
                title: 'Consistency Starter',
                description:
                    'Complete at least one task for 3 consecutive days.',
                unlockedAt: DateTime(2026, 3, 20),
              ),
            ];
          }),
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

  testWidgets('shopping tasks stay visible until linked items are done', (
    WidgetTester tester,
  ) async {
    final tasks = [
      _demoTask(
        id: 7,
        title: 'Weekend groceries',
        slot: TaskSlot.morning,
        status: TaskReminderStatus.completed,
        nextReminderAt: DateTime(2026, 4, 1, 8),
        type: TaskType.shopping,
      ),
    ];
    final repository = _FakeTasksRepository(tasks: tasks);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksControllerProvider.overrideWith(
            () => _FakeTasksController(tasks),
          ),
          shoppingItemsControllerProvider.overrideWith(
            () => _FakeShoppingItemsController([
              ShoppingItem(
                id: 'item-1',
                name: 'Milk',
                category: 'Groceries',
                isCompleted: false,
                linkedTaskId: '7',
                createdAt: DateTime(2026, 3, 31, 9),
              ),
            ]),
          ),
          appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: const MaterialApp(
          home: TasksPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekend groceries'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
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
          rewardEngineProvider.overrideWithValue(_FakeRewardEngine()),
          rewardUserStatsProvider.overrideWith((ref) async {
            return UserStats(
              id: 1,
              currentStreak: 3,
              longestStreak: 5,
              lastCompletedDate: DateTime(2026, 3, 20),
            );
          }),
          rewardAchievementsProvider.overrideWith((ref) async {
            return [
              Achievement(
                id: 'consistency_starter',
                title: 'Consistency Starter',
                description:
                    'Complete at least one task for 3 consecutive days.',
                unlockedAt: DateTime(2026, 3, 20),
              ),
            ];
          }),
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
          behaviorInsightProvider.overrideWith((ref) async {
            return const BehaviorInsight(
              completionRate: 1,
              mostActiveHour: 20,
              mostActiveSlot: TaskSlot.evening,
              suggestedSlot: null,
              overloadWarning: null,
              suggestion: 'You are on a great rhythm.',
            );
          }),
          rewardUserStatsProvider.overrideWith((ref) async {
            return UserStats(
              id: 1,
              currentStreak: 3,
              longestStreak: 5,
              lastCompletedDate: DateTime(2026, 3, 20),
            );
          }),
          rewardAchievementsProvider.overrideWith((ref) async {
            return [
              Achievement(
                id: 'consistency_starter',
                title: 'Consistency Starter',
                description:
                    'Complete at least one task for 3 consecutive days.',
                unlockedAt: DateTime(2026, 3, 20),
              ),
            ];
          }),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('View streaks and achievements'), findsOneWidget);
    await tester.tapAt(const Offset(500, 20));
    await tester.pumpAndSettle();

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

class _FakeTasksController extends TasksController {
  _FakeTasksController(this.tasks);

  final List<Task> tasks;

  @override
  Future<List<Task>> build() async => tasks;
}

class _FakeShoppingItemsController extends ShoppingItemsController {
  _FakeShoppingItemsController(this.items);

  final List<ShoppingItem> items;

  @override
  Future<List<ShoppingItem>> build() async => items;
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
  Future<UserStats> getUserStats() async => UserStats.initial();

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
}

Task _demoTask({
  required int id,
  required String title,
  required TaskSlot slot,
  required TaskReminderStatus status,
  TaskType type = TaskType.normal,
  DateTime? nextReminderAt,
}) {
  return Task(
    id: id,
    title: title,
    notes: null,
    timeLabel: '08:00',
    type: type,
    slot: slot,
    repeat: TaskRepeat.none,
    status: status,
    createdAt: DateTime(2026, 3, 20, 8),
    updatedAt: DateTime(2026, 3, 20, 8),
    nextReminderAt: nextReminderAt ?? DateTime(2026, 3, 20, 8),
    reminderIntervalMinutes: 180,
    reminderIntensity: TaskReminderIntensity.normal,
    ignoredCount: 0,
    completionRate: 0,
  );
}
