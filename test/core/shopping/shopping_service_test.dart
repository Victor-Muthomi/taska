import 'package:flutter_test/flutter_test.dart';

import 'package:taska/core/reminders/reminder_engine.dart';
import 'package:taska/core/settings/app_settings.dart';
import 'package:taska/core/shopping/shopping_service.dart';
import 'package:taska/core/shopping/shopping_event_logger.dart';
import 'package:taska/features/shopping/domain/entities/shopping_item.dart';
import 'package:taska/features/shopping/domain/entities/shopping_session.dart';
import 'package:taska/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';
import 'package:taska/features/tasks/domain/entities/task_log.dart';
import 'package:taska/features/tasks/domain/repositories/tasks_repository.dart';

void main() {
  late _FakeShoppingRepository shoppingRepository;
  late _FakeTasksRepository tasksRepository;
  late _FakeShoppingEventLogger eventLogger;

  setUp(() {
    shoppingRepository = _FakeShoppingRepository();
    tasksRepository = _FakeTasksRepository();
    eventLogger = _FakeShoppingEventLogger();
  });

  test('adds items through the repository after normalization', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    final created = await service.addItem(
      ShoppingItem(
        id: 'item-1',
        name: '  Milk  ',
        category: '  Groceries  ',
        isCompleted: false,
        createdAt: DateTime(2026, 3, 25, 12),
      ),
    );

    expect(created.name, 'Milk');
    expect(created.category, 'Groceries');
    expect(shoppingRepository.items.single.name, 'Milk');
    expect(eventLogger.events, contains('item_added:item-1'));
  });

  test('creates sessions and logs session_created', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    final created = await service.createSession(
      DateTime(2026, 3, 25),
      'Groceries',
    );

    expect(created.status, ShoppingSessionStatus.active);
    expect(shoppingRepository.sessions[created.id], isNotNull);
    expect(eventLogger.events, contains('session_created:${created.id}'));
  });

  test('creates empty sessions and clones them without items', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    shoppingRepository.sessions['session-1'] = ShoppingSession(
      id: 'session-1',
      date: DateTime(2026, 3, 20),
      title: 'Empty session',
      status: ShoppingSessionStatus.completed,
      createdAt: DateTime(2026, 3, 20, 8),
    );

    final cloned = await service.cloneSession('session-1');

    expect(cloned.status, ShoppingSessionStatus.active);
    expect(shoppingRepository.items, isEmpty);
    expect(eventLogger.events, contains('session_created:${cloned.id}'));
  });

  test('suggests frequent items added three times in seven days', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    shoppingRepository.items.addAll([
      ShoppingItem(
        id: '1',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: false,
        createdAt: DateTime(2026, 3, 20),
      ),
      ShoppingItem(
        id: '2',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: false,
        createdAt: DateTime(2026, 3, 22),
      ),
      ShoppingItem(
        id: '3',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: true,
        createdAt: DateTime(2026, 3, 24),
      ),
    ]);

    final suggestions = await service.suggestItems();

    expect(suggestions, hasLength(1));
    expect(suggestions.single.name, 'Milk');
  });

  test('preloads items for recurring linked tasks', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    tasksRepository.tasks.add(
      Task(
        id: 7,
        title: 'Weekly groceries',
        notes: null,
        timeLabel: '08:00',
        type: TaskType.normal,
        slot: TaskSlot.morning,
        repeat: TaskRepeat.weekly,
        status: TaskReminderStatus.pending,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
        nextReminderAt: DateTime(2026, 3, 1),
        reminderIntervalMinutes: 180,
        reminderIntensity: TaskReminderIntensity.normal,
        ignoredCount: 0,
        completionRate: 0,
      ),
    );
    shoppingRepository.items.add(
      ShoppingItem(
        id: 'linked-1',
        name: 'Eggs',
        category: 'Groceries',
        isCompleted: false,
        linkedTaskId: '7',
        createdAt: DateTime(2026, 3, 24),
      ),
    );

    final suggestions = await service.suggestItems();

    expect(suggestions.single.id, 'linked-1');
    expect(suggestions.single.linkedTaskId, '7');
  });

  test('marks items as completed', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    shoppingRepository.items.add(
      ShoppingItem(
        id: 'done-1',
        name: 'Bread',
        category: 'Groceries',
        isCompleted: false,
        createdAt: DateTime(2026, 3, 24),
      ),
    );

    await service.markAsCompleted('done-1');

    expect(shoppingRepository.completedIds, contains('done-1'));
    expect(eventLogger.events, contains('item_completed:done-1'));
  });

  test('ignores duplicate items within the same session', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    shoppingRepository.sessions['session-1'] = ShoppingSession(
      id: 'session-1',
      date: DateTime(2026, 3, 25),
      title: 'Groceries',
      status: ShoppingSessionStatus.active,
      createdAt: DateTime(2026, 3, 25, 8),
    );

    final first = await service.addItem(
      ShoppingItem(
        id: 'item-1',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: false,
        sessionId: 'session-1',
        createdAt: DateTime(2026, 3, 25, 9),
      ),
    );
    final second = await service.addItem(
      ShoppingItem(
        id: 'item-2',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: false,
        sessionId: 'session-1',
        createdAt: DateTime(2026, 3, 25, 10),
      ),
    );

    expect(second.id, first.id);
    expect(shoppingRepository.items, hasLength(1));
    expect(eventLogger.events.where((event) => event.startsWith('item_added:')),
      hasLength(1));
  });

  test('rejects invalid session references when adding items', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    expect(
      () => service.addItem(
        ShoppingItem(
          id: 'item-1',
          name: 'Milk',
          category: 'Groceries',
          isCompleted: false,
          sessionId: 'missing-session',
          createdAt: DateTime(2026, 3, 25, 9),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('duplicates sessions and clones items as a fresh active session', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    shoppingRepository.sessions['session-1'] = ShoppingSession(
      id: 'session-1',
      date: DateTime(2026, 3, 25),
      title: 'Groceries',
      status: ShoppingSessionStatus.completed,
      createdAt: DateTime(2026, 3, 25, 8),
    );
    shoppingRepository.items.add(
      ShoppingItem(
        id: 'item-1',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: true,
        sessionId: 'session-1',
        createdAt: DateTime(2026, 3, 25, 9),
      ),
    );

    final duplicated = await service.duplicateSession('session-1');

    expect(duplicated.status, ShoppingSessionStatus.active);
    expect(shoppingRepository.sessions[duplicated.id], isNotNull);
    expect(shoppingRepository.items, hasLength(2));
    final clonedItem = shoppingRepository.items
        .firstWhere((item) => item.sessionId == duplicated.id);
    expect(clonedItem.isCompleted, isFalse);
    expect(clonedItem.name, 'Milk');
    expect(clonedItem.id, isNot('item-1'));
  });

  test('clones sessions using today and keeps copied items active', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12, 30),
    );

    shoppingRepository.sessions['session-1'] = ShoppingSession(
      id: 'session-1',
      date: DateTime(2026, 3, 20),
      title: 'Groceries',
      status: ShoppingSessionStatus.completed,
      createdAt: DateTime(2026, 3, 20, 8),
    );
    shoppingRepository.items.add(
      ShoppingItem(
        id: 'item-1',
        name: 'Eggs',
        category: 'Groceries',
        isCompleted: true,
        sessionId: 'session-1',
        createdAt: DateTime(2026, 3, 20, 9),
      ),
    );

    final cloned = await service.cloneSession('session-1');

    expect(cloned.status, ShoppingSessionStatus.active);
    expect(cloned.date, DateTime(2026, 3, 25));
    expect(cloned.title, 'Groceries');
    expect(shoppingRepository.items, hasLength(2));

    final clonedItem = shoppingRepository.items.firstWhere(
      (item) => item.sessionId == cloned.id,
    );
    expect(clonedItem.isCompleted, isFalse);
    expect(clonedItem.name, 'Eggs');
  });

  test('updates and deletes items in active sessions', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    shoppingRepository.sessions['session-1'] = ShoppingSession(
      id: 'session-1',
      date: DateTime(2026, 3, 25),
      title: 'Groceries',
      status: ShoppingSessionStatus.active,
      createdAt: DateTime(2026, 3, 25, 8),
    );
    shoppingRepository.items.add(
      ShoppingItem(
        id: 'item-1',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: false,
        sessionId: 'session-1',
        createdAt: DateTime(2026, 3, 25, 9),
      ),
    );

    await service.updateItem(
      ShoppingItem(
        id: 'item-1',
        name: 'Oat Milk',
        category: 'Groceries',
        isCompleted: false,
        sessionId: 'session-1',
        createdAt: DateTime(2026, 3, 25, 10),
      ),
    );

    expect(shoppingRepository.items.single.name, 'Oat Milk');
    expect(eventLogger.events, contains('item_updated:item-1'));

    await service.toggleItemCompletion('item-1');
    expect(shoppingRepository.items.single.isCompleted, isTrue);
    expect(eventLogger.events, contains('item_updated:item-1'));

    await service.toggleItemCompletion('item-1');
    expect(shoppingRepository.items.single.isCompleted, isFalse);
    expect(
      eventLogger.events.where((event) => event == 'item_updated:item-1'),
      hasLength(3),
    );

    await service.deleteItem('item-1');
    expect(shoppingRepository.items, isEmpty);
  });

  test('allows item changes in completed sessions', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    shoppingRepository.sessions['session-1'] = ShoppingSession(
      id: 'session-1',
      date: DateTime(2026, 3, 25),
      title: 'Groceries',
      status: ShoppingSessionStatus.completed,
      createdAt: DateTime(2026, 3, 25, 8),
    );
    shoppingRepository.items.add(
      ShoppingItem(
        id: 'item-1',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: false,
        sessionId: 'session-1',
        createdAt: DateTime(2026, 3, 25, 9),
      ),
    );

    await service.updateItem(
      ShoppingItem(
        id: 'item-1',
        name: 'Oat Milk',
        category: 'Groceries',
        isCompleted: false,
        sessionId: 'session-1',
        createdAt: DateTime(2026, 3, 25, 10),
      ),
    );

    await service.toggleItemCompletion('item-1');
    await service.deleteItem('item-1');

    expect(shoppingRepository.items, isEmpty);
    expect(
      eventLogger.events.where((event) => event == 'item_updated:item-1'),
      hasLength(2),
    );
  });

  test('allows session edits and deletes for completed sessions', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    shoppingRepository.sessions['session-1'] = ShoppingSession(
      id: 'session-1',
      date: DateTime(2026, 3, 25),
      title: 'Groceries',
      status: ShoppingSessionStatus.completed,
      createdAt: DateTime(2026, 3, 25, 8),
    );

    await service.updateSession(
      ShoppingSession(
        id: 'session-1',
        date: DateTime(2026, 3, 26),
        title: 'Changed',
        status: ShoppingSessionStatus.completed,
        createdAt: DateTime(2026, 3, 25, 8),
      ),
    );

    expect(shoppingRepository.sessions['session-1']!.title, 'Changed');

    await service.deleteSession('session-1');
    expect(shoppingRepository.sessions['session-1'], isNull);
  });

  test('updates sessions without changing editability rules', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    shoppingRepository.sessions['session-1'] = ShoppingSession(
      id: 'session-1',
      date: DateTime(2026, 3, 25),
      title: 'Groceries',
      status: ShoppingSessionStatus.active,
      createdAt: DateTime(2026, 3, 25, 8),
    );

    await service.updateSession(
      shoppingRepository.sessions['session-1']!.copyWith(
        title: 'Groceries updated',
      ),
    );

    expect(
      shoppingRepository.sessions['session-1']!.title,
      'Groceries updated',
    );
    expect(eventLogger.events, isEmpty);
  });

  test('moves linked shopping tasks to the evening slot when items remain incomplete', () async {
    final service = ShoppingService(
      shoppingRepository: shoppingRepository,
      tasksRepository: tasksRepository,
      eventLogger: eventLogger,
      reminderEngine: ReminderEngine(settings: AppSettings.defaults()),
      now: () => DateTime(2026, 3, 25, 12),
    );

    tasksRepository.tasks.add(
      Task(
        id: 9,
        title: 'Groceries',
        notes: null,
        timeLabel: '08:00',
        type: TaskType.shopping,
        slot: TaskSlot.morning,
        repeat: TaskRepeat.none,
        status: TaskReminderStatus.pending,
        createdAt: DateTime(2026, 3, 25, 8),
        updatedAt: DateTime(2026, 3, 25, 8),
        nextReminderAt: DateTime(2026, 3, 25, 8),
        reminderIntervalMinutes: 180,
        reminderIntensity: TaskReminderIntensity.normal,
        ignoredCount: 0,
        completionRate: 0,
      ),
    );

    await service.addItem(
      ShoppingItem(
        id: 'milk-1',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: false,
        linkedTaskId: '9',
        createdAt: DateTime(2026, 3, 25, 12),
      ),
    );

    final updatedTask = tasksRepository.tasks.single;
    expect(updatedTask.slot, TaskSlot.evening);
    expect(updatedTask.timeLabel, '17:00');
    expect(updatedTask.nextReminderAt.hour, 17);
  });
}

class _FakeShoppingEventLogger implements ShoppingEventLogger {
  final List<String> events = [];

  @override
  Future<void> logSessionCreated(ShoppingSession session) async {
    events.add('session_created:${session.id}');
  }

  @override
  Future<void> logItemAdded(ShoppingItem item) async {
    events.add('item_added:${item.id}');
  }

  @override
  Future<void> logItemUpdated(ShoppingItem item) async {
    events.add('item_updated:${item.id}');
  }

  @override
  Future<void> logItemCompleted(ShoppingItem item) async {
    events.add('item_completed:${item.id}');
  }
}

class _FakeShoppingRepository implements ShoppingRepository {
  final List<ShoppingItem> items = [];
  final Set<String> completedIds = {};
  final Map<String, ShoppingSession> sessions = {};

  @override
  Future<ShoppingItem> addItem(ShoppingItem item) async {
    items.add(item);
    return item;
  }

  @override
  Future<ShoppingSession> createSession(DateTime date, String title) {
    final session = ShoppingSession(
      id: 'session-${sessions.length + 1}',
      date: date,
      title: title,
      status: ShoppingSessionStatus.active,
      createdAt: DateTime(2026, 3, 25, 12),
    );
    sessions[session.id] = session;
    return Future.value(session);
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
  Future<ShoppingSession?> getSessionById(String id) async {
    return sessions[id];
  }

  @override
  Future<void> deleteItem(String itemId) async {
    items.removeWhere((item) => item.id == itemId);
  }

  @override
  Future<void> deleteSession(String id) {
    sessions.remove(id);
    return Future.value();
  }

  @override
  Future<List<ShoppingSession>> getSessions() {
    return Future.value(List<ShoppingSession>.unmodifiable(sessions.values));
  }

  @override
  Future<void> updateSession(ShoppingSession session) {
    sessions[session.id] = session;
    return Future.value();
  }

  @override
  Future<ShoppingItem> updateItem(ShoppingItem item) async {
    final index = items.indexWhere((candidate) => candidate.id == item.id);
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }

    if (item.isCompleted) {
      completedIds.add(item.id);
    } else {
      completedIds.remove(item.id);
    }

    return item;
  }

  @override
  Future<List<ShoppingItem>> getItems() async {
    return List<ShoppingItem>.unmodifiable(items);
  }

  @override
  Future<List<ShoppingItem>> getItemsBySession(String sessionId) async {
    return items.where((item) => item.sessionId == sessionId).toList();
  }

  @override
  Future<List<ShoppingItem>> getItemsByTask(String taskId) async {
    return items.where((item) => item.linkedTaskId == taskId).toList();
  }

  @override
  Future<void> updateItemStatus({
    required String itemId,
    required bool isCompleted,
  }) async {
    if (isCompleted) {
      completedIds.add(itemId);
    } else {
      completedIds.remove(itemId);
    }
    final index = items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      items[index] = items[index].copyWith(isCompleted: isCompleted);
    }
  }
}

class _FakeTasksRepository implements TasksRepository {
  final List<Task> tasks = [];

  @override
  Future<Task> createTask(Task task) => throw UnimplementedError();

  @override
  Future<void> deleteTask(int taskId) => throw UnimplementedError();

  @override
  Future<List<TaskLog>> getAllTaskLogs() => throw UnimplementedError();

  @override
  Future<List<Task>> getTasks() async {
    return List<Task>.unmodifiable(tasks);
  }

  @override
  Future<List<TaskLog>> getTaskLogs(int taskId) => throw UnimplementedError();

  @override
  Future<void> logTaskAction(TaskLog log) => throw UnimplementedError();

  @override
  Future<void> updateTask(Task task) async {
    final index = tasks.indexWhere((candidate) => candidate.id == task.id);
    if (index == -1) {
      tasks.add(task);
      return;
    }

    tasks[index] = task;
  }

  @override
  Future<void> updateTaskStatus({
    required int taskId,
    required TaskReminderStatus status,
  }) => throw UnimplementedError();
}