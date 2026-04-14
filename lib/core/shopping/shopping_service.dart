import 'dart:math';

import '../reminders/reminder_engine.dart';
import '../../features/shopping/domain/entities/shopping_item.dart';
import '../../features/shopping/domain/entities/shopping_session.dart';
import '../../features/shopping/domain/repositories/shopping_repository.dart';
import '../../features/tasks/domain/entities/task.dart';
import '../../features/tasks/domain/repositories/tasks_repository.dart';
import 'shopping_event_logger.dart';

class ShoppingService {
  ShoppingService({
    required ShoppingRepository shoppingRepository,
    required TasksRepository tasksRepository,
    required ShoppingEventLogger eventLogger,
      required ReminderEngine reminderEngine,
    DateTime Function()? now,
  })  : _shoppingRepository = shoppingRepository,
        _tasksRepository = tasksRepository,
        _eventLogger = eventLogger,
      _reminderEngine = reminderEngine,
        _now = now ?? DateTime.now;

  final ShoppingRepository _shoppingRepository;
  final TasksRepository _tasksRepository;
  final ShoppingEventLogger _eventLogger;
    final ReminderEngine _reminderEngine;
  final DateTime Function() _now;

  Future<ShoppingSession> createSession(DateTime date, String title) async {
    final createdSession = await _shoppingRepository.createSession(date, title);
    await _eventLogger.logSessionCreated(createdSession);
    return createdSession;
  }

  Future<List<ShoppingSession>> getSessionsWithResolvedStatus() async {
    final sessions = await _shoppingRepository.getSessions();
    for (final session in sessions) {
      await _resolveCompletionStatusForDueSession(session);
    }
    return _shoppingRepository.getSessions();
  }

  Future<ShoppingItem> addItem(ShoppingItem item) {
    final normalized = _normalizeItem(item);
    final itemWithId = normalized.id.isEmpty
        ? normalized.copyWith(id: _createUuid())
        : normalized;

    return _addItemValidated(itemWithId).then((result) async {
      if (result.created) {
        await _eventLogger.logItemAdded(result.item);
      }
      if (result.item.linkedTaskId != null) {
        await syncLinkedTaskReminder(result.item.linkedTaskId!);
      }
      return result.item;
    });
  }

  Future<void> markAsCompleted(String itemId) async {
    await toggleItemCompletion(itemId);
  }

  Future<void> updateItem(ShoppingItem item) async {
    final existingItem = await _findItem(item.id);
    final candidateItem = existingItem == null
        ? _normalizeItem(item)
        : _normalizeItem(item).copyWith(
            createdAt: existingItem.createdAt,
            sessionId: item.sessionId ?? existingItem.sessionId,
          );

    await _ensureSessionReferenceValid(candidateItem.sessionId);
    await _ensureNoDuplicateItem(candidateItem);
    await _shoppingRepository.updateItem(candidateItem);
    await _eventLogger.logItemUpdated(candidateItem);

    final linkedTaskId = candidateItem.linkedTaskId;
    if (linkedTaskId != null) {
      await syncLinkedTaskReminder(linkedTaskId);
    }
  }

  Future<void> updateSession(ShoppingSession session) async {
    final existingSession = await _shoppingRepository.getSessionById(session.id);
    if (existingSession == null) {
      return;
    }

    await _shoppingRepository.updateSession(
      existingSession.copyWith(
        date: session.date,
        title: session.title,
      ),
    );
  }

  Future<ShoppingSession> duplicateSession(
    String sessionId, {
    DateTime? date,
    String? title,
  }) async {
    final sourceSession = await _shoppingRepository.getSessionById(sessionId);
    if (sourceSession == null) {
      throw StateError('Shopping session not found.');
    }

    final duplicatedSession = await createSession(
      date ?? sourceSession.date,
      title ?? sourceSession.title,
    );

    final sourceItems = await _shoppingRepository.getItemsBySession(sessionId);
    for (final item in sourceItems) {
      await _shoppingRepository.addItem(
        item.copyWith(
          id: _createUuid(),
          sessionId: duplicatedSession.id,
          isCompleted: false,
          createdAt: _now().toUtc(),
        ),
      );
    }

    return duplicatedSession;
  }

  Future<ShoppingSession> cloneSession(String oldSessionId) async {
    final sourceSession = await _shoppingRepository.getSessionById(oldSessionId);
    if (sourceSession == null) {
      throw StateError('Shopping session not found.');
    }

    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    return duplicateSession(
      oldSessionId,
      date: today,
      title: sourceSession.title,
    );
  }

  Future<void> toggleItemCompletion(String itemId) async {
    final item = await _findItem(itemId);
    if (item == null) {
      return;
    }

    final updatedItem = item.copyWith(isCompleted: !item.isCompleted);
    await _shoppingRepository.updateItem(updatedItem);
    await _eventLogger.logItemUpdated(updatedItem);
    if (updatedItem.isCompleted) {
      await _eventLogger.logItemCompleted(updatedItem);
    }
    if (updatedItem.linkedTaskId != null) {
      await syncLinkedTaskReminder(updatedItem.linkedTaskId!);
    }

    await _resolveCompletionStatusBySessionId(updatedItem.sessionId);
  }

  Future<void> setCompleted(ShoppingItem item, bool completed) async {
    if (completed) {
      await toggleItemCompletion(item.id);
      return;
    }

    final existingItem = await _findItem(item.id);
    final updatedItem = (existingItem ?? item).copyWith(isCompleted: false);
    await _ensureSessionReferenceValid(updatedItem.sessionId);
    await _shoppingRepository.updateItem(updatedItem);
    await _eventLogger.logItemUpdated(updatedItem);
    if (updatedItem.linkedTaskId != null) {
      await syncLinkedTaskReminder(updatedItem.linkedTaskId!);
    }

    await _resolveCompletionStatusBySessionId(updatedItem.sessionId);
  }

  Future<void> deleteItem(String itemId) async {
    final item = await _findItem(itemId);
    await _shoppingRepository.deleteItem(itemId);
    if (item?.linkedTaskId != null) {
      await syncLinkedTaskReminder(item!.linkedTaskId!);
    }
  }

  Future<void> deleteSession(String sessionId) async {
    final session = await _shoppingRepository.getSessionById(sessionId);
    if (session == null) {
      return;
    }

    if (session.status == ShoppingSessionStatus.active) {
      throw StateError(
        'Cannot delete an active shopping list. Complete it first.',
      );
    }

    final sessionItems = await _shoppingRepository.getItemsBySession(sessionId);
    for (final item in sessionItems) {
      await deleteItem(item.id);
    }

    await _shoppingRepository.deleteSession(sessionId);
  }

  Future<void> syncLinkedTaskReminder(String taskId) async {
    final task = await _findTask(taskId);
    if (task == null || task.type != TaskType.shopping) {
      return;
    }

    final linkedItems = await _shoppingRepository.getItemsByTask(taskId);
    final hasIncompleteItems = linkedItems.any((item) => !item.isCompleted);
    if (!hasIncompleteItems) {
      return;
    }

    final updatedTask = _reminderEngine.applyShoppingItemRules(
      task,
      hasIncompleteItems: true,
      from: _now(),
    );
    await _tasksRepository.updateTask(updatedTask);
  }

  Future<List<ShoppingItem>> suggestItems() async {
    final items = await _shoppingRepository.getItems();
    final tasks = await _tasksRepository.getTasks();
    final cutoff = _now().toUtc().subtract(const Duration(days: 7));
    final suggestionsById = <String, ShoppingItem>{};

    _addFrequentItemSuggestions(
      items: items,
      cutoff: cutoff,
      suggestionsById: suggestionsById,
    );
    await _addRecurringTaskSuggestions(
      tasks: tasks,
      suggestionsById: suggestionsById,
    );

    final suggestions = suggestionsById.values.toList();
    suggestions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return suggestions;
  }

  ShoppingItem _normalizeItem(ShoppingItem item) {
    final normalizedPrice = item.pricePerItem;
    return item.copyWith(
      name: item.name.trim(),
      category: item.category.trim().isEmpty ? 'General' : item.category.trim(),
      quantity: item.quantity < 1 ? 1 : item.quantity,
      pricePerItem: normalizedPrice == null
          ? null
          : (normalizedPrice < 0 ? 0 : normalizedPrice),
      linkedTaskId: item.linkedTaskId?.trim().isEmpty == true
          ? null
          : item.linkedTaskId?.trim(),
    );
  }

  Future<ShoppingItem?> _findItem(String itemId) async {
    return _shoppingRepository.getItemById(itemId);
  }

  Future<({ShoppingItem item, bool created})> _addItemValidated(
    ShoppingItem item,
  ) async {
    await _ensureSessionReferenceValid(item.sessionId);
    final duplicate = await _findDuplicateItem(item);
    if (duplicate != null) {
      return (item: duplicate, created: false);
    }

    final created = await _shoppingRepository.addItem(item);
    return (item: created, created: true);
  }

  Future<void> _ensureSessionReferenceValid(String? sessionId) async {
    if (sessionId == null) {
      return;
    }

    final session = await _shoppingRepository.getSessionById(sessionId);
    if (session == null) {
      throw StateError('Invalid shopping session reference.');
    }
  }

  Future<ShoppingItem?> _findDuplicateItem(ShoppingItem candidate) async {
    final sessionId = candidate.sessionId;
    if (sessionId == null) {
      return null;
    }

    final sessionItems = await _shoppingRepository.getItemsBySession(sessionId);
    for (final item in sessionItems) {
      if (item.id == candidate.id) {
        continue;
      }
      if (_isSameShoppingItem(item, candidate)) {
        return item;
      }
    }

    return null;
  }

  Future<void> _ensureNoDuplicateItem(ShoppingItem candidate) async {
    final duplicate = await _findDuplicateItem(candidate);
    if (duplicate != null) {
      throw StateError('Duplicate shopping item in session.');
    }
  }

  Future<void> _resolveCompletionStatusBySessionId(String? sessionId) async {
    if (sessionId == null) {
      return;
    }
    final session = await _shoppingRepository.getSessionById(sessionId);
    if (session == null) {
      return;
    }
    await _resolveCompletionStatusForDueSession(session);
  }

  Future<void> _resolveCompletionStatusForDueSession(
    ShoppingSession session,
  ) async {
    if (session.status == ShoppingSessionStatus.completed) {
      return;
    }

    final today = _dateOnly(_now());
    final sessionDate = _dateOnly(session.date);
    if (sessionDate.isAfter(today)) {
      return;
    }

    final items = await _shoppingRepository.getItemsBySession(session.id);
    if (items.isEmpty) {
      return;
    }

    final allCompleted = items.every((item) => item.isCompleted);
    if (!allCompleted) {
      return;
    }

    await _shoppingRepository.updateSession(
      session.copyWith(status: ShoppingSessionStatus.completed),
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameShoppingItem(ShoppingItem left, ShoppingItem right) {
    return left.name.toLowerCase() == right.name.toLowerCase() &&
        left.category.toLowerCase() == right.category.toLowerCase() &&
        left.linkedTaskId == right.linkedTaskId &&
        left.sessionId == right.sessionId;
  }


  Future<Task?> _findTask(String taskId) async {
    final parsedTaskId = int.tryParse(taskId);
    if (parsedTaskId == null) {
      return null;
    }

    final tasks = await _tasksRepository.getTasks();
    for (final task in tasks) {
      if (task.id == parsedTaskId) {
        return task;
      }
    }

    return null;
  }

  void _addFrequentItemSuggestions({
    required List<ShoppingItem> items,
    required DateTime cutoff,
    required Map<String, ShoppingItem> suggestionsById,
  }) {
    final recentItems = items.where(
      (item) => !item.createdAt.toUtc().isBefore(cutoff),
    );
    final grouped = <String, List<ShoppingItem>>{};

    for (final item in recentItems) {
      final key = _itemKey(item);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    for (final entry in grouped.entries) {
      if (entry.value.length < 3) {
        continue;
      }

      final representative = entry.value.reduce(
        (latest, candidate) =>
            candidate.createdAt.isAfter(latest.createdAt) ? candidate : latest,
      );
      suggestionsById.putIfAbsent(representative.id, () => representative);
    }
  }

  Future<void> _addRecurringTaskSuggestions({
    required List<Task> tasks,
    required Map<String, ShoppingItem> suggestionsById,
  }) async {
    final recurringTaskIds = tasks
        .where((task) => task.repeat != TaskRepeat.none)
        .map((task) => task.id)
        .whereType<int>()
        .map((taskId) => taskId.toString())
        .toSet();

    for (final taskId in recurringTaskIds) {
      final linkedItems = await _shoppingRepository.getItemsByTask(taskId);
      for (final item in linkedItems) {
        suggestionsById.putIfAbsent(item.id, () => item);
      }
    }
  }

  String _itemKey(ShoppingItem item) {
    return '${item.name.toLowerCase()}|${item.category.toLowerCase()}';
  }

  String _createUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');

    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }
}