import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taska/app/app.dart';
import 'package:taska/core/reminders/reminder_engine.dart';
import 'package:taska/core/shopping/shopping_event_logger.dart';
import 'package:taska/core/shopping/shopping_service.dart';
import 'package:taska/core/shopping/shopping_service_providers.dart';
import 'package:taska/core/notifications/notification_channels.dart';
import 'package:taska/core/notifications/notification_providers.dart';
import 'package:taska/core/notifications/notification_service.dart';
import 'package:taska/core/settings/app_settings.dart';
import 'package:taska/core/settings/app_settings_providers.dart';
import 'package:taska/core/settings/app_settings_storage.dart';
import 'package:taska/features/shopping/domain/entities/shopping_item.dart';
import 'package:taska/features/shopping/domain/entities/shopping_session.dart';
import 'package:taska/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';
import 'package:taska/features/tasks/domain/entities/task_log.dart';
import 'package:taska/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:taska/features/tasks/presentation/providers/tasks_providers.dart';
import 'package:taska/features/tasks/presentation/widgets/task_sidebar_drawer.dart';

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

  testWidgets(
    'sidebar opens calendar screen and data actions remain available',
    (tester) async {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day, 23);
      final tomorrowDate = todayDate.add(const Duration(days: 1));
      final shoppingRepository = _FakeShoppingRepository();

      final repository = _FakeTasksRepository(
        tasks: [
          _task(id: 1, title: 'Today task', nextReminderAt: todayDate),
          _task(id: 2, title: 'Tomorrow task', nextReminderAt: tomorrowDate),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksControllerProvider.overrideWith(
              () => _FakeTasksController(repository.tasks),
            ),
            tasksRepositoryProvider.overrideWithValue(repository),
            shoppingRepositoryProvider.overrideWithValue(shoppingRepository),
            shoppingServiceProvider.overrideWithValue(
              ShoppingService(
                shoppingRepository: shoppingRepository,
                tasksRepository: repository,
                eventLogger: _FakeShoppingEventLogger(),
                reminderEngine: ReminderEngine(
                  settings: AppSettings.defaults(),
                ),
              ),
            ),
            appSettingsStorageProvider.overrideWithValue(
              _FakeSettingsStorage(),
            ),
            notificationServiceProvider.overrideWithValue(
              _FakeNotificationService(),
            ),
          ],
          child: const MyApp(),
        ),
      );
      await _pumpUntilText(tester, 'Sidebar');

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sidebar'), findsOneWidget);
      expect(find.text('Export JSON'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byTooltip('Open calendar'),
        48,
        scrollable: find.byType(Scrollable).last,
      );
    },
  );

  testWidgets('sidebar shows shopping lists from stored sessions', (
    tester,
  ) async {
    final tasksRepository = _FakeTasksRepository();
    final shoppingRepository = _FakeShoppingRepository(
      sessions: [
        ShoppingSession(
          id: 'session-1',
          date: DateTime(2026, 3, 30),
          title: 'Weekend groceries',
          status: ShoppingSessionStatus.active,
          createdAt: DateTime(2026, 3, 30, 8),
        ),
        ShoppingSession(
          id: 'session-2',
          date: DateTime(2026, 3, 28),
          title: 'Party supplies',
          status: ShoppingSessionStatus.completed,
          createdAt: DateTime(2026, 3, 28, 8),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksControllerProvider.overrideWith(
            () => _FakeTasksController(tasksRepository.tasks),
          ),
          tasksRepositoryProvider.overrideWithValue(tasksRepository),
          shoppingRepositoryProvider.overrideWithValue(shoppingRepository),
          shoppingServiceProvider.overrideWithValue(
            ShoppingService(
              shoppingRepository: shoppingRepository,
              tasksRepository: tasksRepository,
              eventLogger: _FakeShoppingEventLogger(),
              reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
            ),
          ),
          appSettingsStorageProvider.overrideWithValue(_FakeSettingsStorage()),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(),
            body: const Text('Home'),
            drawer: const TaskSidebarDrawer(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Shopping lists'), findsOneWidget);
    expect(find.text('Weekend groceries'), findsOneWidget);
    expect(find.text('Party supplies'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
  });
}

Future<void> _pumpUntilText(WidgetTester tester, String text) async {
  for (var i = 0; i < 60; i++) {
    if (find.text(text).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _FakeTasksRepository implements TasksRepository {
  _FakeTasksRepository({
    List<Task>? tasks,
    List<Task>? taskList,
    List<TaskLog>? logs,
  }) : tasks = tasks ?? taskList ?? [],
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

class _FakeShoppingEventLogger implements ShoppingEventLogger {
  @override
  Future<void> logItemAdded(ShoppingItem item) async {}

  @override
  Future<void> logItemCompleted(ShoppingItem item) async {}

  @override
  Future<void> logItemUpdated(ShoppingItem item) async {}

  @override
  Future<void> logSessionCreated(ShoppingSession session) async {}
}

class _FakeShoppingRepository implements ShoppingRepository {
  _FakeShoppingRepository({
    List<ShoppingSession>? sessions,
    List<ShoppingItem>? items,
  }) : sessions = {
         for (final session in sessions ?? <ShoppingSession>[])
           session.id: session,
       },
       items = List<ShoppingItem>.from(items ?? const []);

  final Map<String, ShoppingSession> sessions;
  final List<ShoppingItem> items;

  @override
  Future<ShoppingItem> addItem(ShoppingItem item) async {
    items.add(item);
    return item;
  }

  @override
  Future<ShoppingSession> createSession(DateTime date, String title) async {
    final session = ShoppingSession(
      id: 'session-${sessions.length + 1}',
      date: date,
      title: title,
      status: ShoppingSessionStatus.active,
      createdAt: DateTime(2026, 3, 30, 8),
    );
    sessions[session.id] = session;
    return session;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    items.removeWhere((item) => item.id == itemId);
  }

  @override
  Future<void> deleteSession(String id) async {
    sessions.remove(id);
  }

  @override
  Future<ShoppingItem?> getItemById(String id) async {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<ShoppingItem>> getItems() async => List<ShoppingItem>.from(items);

  @override
  Future<List<ShoppingItem>> getItemsBySession(String sessionId) async {
    return items.where((item) => item.sessionId == sessionId).toList();
  }

  @override
  Future<List<ShoppingItem>> getItemsByTask(String taskId) async {
    return items.where((item) => item.linkedTaskId == taskId).toList();
  }

  @override
  Future<ShoppingSession?> getSessionById(String id) async => sessions[id];

  @override
  Future<List<ShoppingSession>> getSessions() async {
    final values = sessions.values.toList()
      ..sort((left, right) => right.date.compareTo(left.date));
    return values;
  }

  @override
  Future<ShoppingItem> updateItem(ShoppingItem item) async {
    final index = items.indexWhere((candidate) => candidate.id == item.id);
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }
    return item;
  }

  @override
  Future<void> updateItemStatus({
    required String itemId,
    required bool isCompleted,
  }) async {
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }
    items[index] = items[index].copyWith(isCompleted: isCompleted);
  }

  @override
  Future<void> updateSession(ShoppingSession session) async {
    sessions[session.id] = session;
  }
}

class _FakeTasksController extends TasksController {
  _FakeTasksController(this.tasks);

  final List<Task> tasks;

  @override
  Future<List<Task>> build() async => tasks;
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
