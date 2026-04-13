import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shopping/shopping_service_providers.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_session.dart';
import '../../domain/repositories/shopping_repository.dart';
import '../contracts/shopping_session_contracts.dart';
import '../../../tasks/presentation/providers/tasks_providers.dart';

final shoppingItemsControllerProvider =
    AsyncNotifierProvider<ShoppingItemsController, List<ShoppingItem>>(
      ShoppingItemsController.new,
    );

final shoppingSessionsProvider = FutureProvider<List<ShoppingSession>>((ref) {
  return ref.watch(shoppingServiceProvider).getSessionsWithResolvedStatus();
});

final shoppingSuggestionsProvider = FutureProvider<List<ShoppingItem>>((ref) {
  return ref.watch(shoppingServiceProvider).suggestItems();
});

class ShoppingItemsController extends AsyncNotifier<List<ShoppingItem>>
    implements ActiveShoppingSessionContract, ShoppingSessionCloneAction {
  ShoppingSession? _session;
  List<ShoppingItem> _sessionItems = const [];

  @override
  Future<List<ShoppingItem>> build() async {
    return _loadItems();
  }

  @override
  ShoppingSession get session {
    final loadedSession = _session;
    if (loadedSession == null) {
      throw StateError('No shopping session is loaded.');
    }
    return loadedSession;
  }

  @override
  List<ShoppingItem> get items => _sessionItems;

  Future<void> loadSession(String sessionId) async {
    final repository = ref.read(shoppingRepositoryProvider);
    final loadedSession = await repository.getSessionById(sessionId);
    if (loadedSession == null) {
      throw StateError('Shopping session not found.');
    }

    _session = loadedSession;
    _sessionItems = await repository.getItemsBySession(sessionId);
    await _refreshTaskController();
  }

  Future<void> addItem({
    required String name,
    String category = 'General',
    int quantity = 1,
    double? pricePerItem,
    String? linkedTaskId,
    String? sessionId,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    await ref
        .read(shoppingServiceProvider)
        .addItem(
          ShoppingItem(
            id: '',
            name: trimmedName,
            category: category.trim().isEmpty ? 'General' : category.trim(),
            quantity: quantity < 1 ? 1 : quantity,
            pricePerItem: (pricePerItem != null && pricePerItem >= 0)
              ? pricePerItem
              : null,
            isCompleted: false,
            linkedTaskId: linkedTaskId,
            sessionId: sessionId,
            createdAt: DateTime.now(),
          ),
        );
    await _refreshTaskController();
    await _refresh();
  }

  Future<void> addSuggestedItem(
    ShoppingItem suggestion, {
    String? sessionId,
  }) async {
    await addItem(
      name: suggestion.name,
      category: suggestion.category,
      quantity: suggestion.quantity,
      pricePerItem: suggestion.pricePerItem,
      linkedTaskId: suggestion.linkedTaskId,
      sessionId: sessionId,
    );
  }

  Future<ShoppingSession> createSession(DateTime date, String title) async {
    final createdSession = await ref
        .read(shoppingServiceProvider)
        .createSession(date, title);
    await _refreshTaskController();
    await _refresh();
    return createdSession;
  }

  Future<void> updateSession(ShoppingSession session) async {
    await ref.read(shoppingServiceProvider).updateSession(session);
    await _refreshTaskController();
    await _refresh();
  }

  Future<ShoppingSession> duplicateSession(
    String sessionId, {
    DateTime? date,
    String? title,
  }) async {
    final duplicatedSession = await ref
        .read(shoppingServiceProvider)
        .duplicateSession(sessionId, date: date, title: title);
    await _refreshTaskController();
    await _refresh();
    return duplicatedSession;
  }

  Future<ShoppingSession> cloneSession(String oldSessionId) async {
    final clonedSession = await ref
        .read(shoppingServiceProvider)
        .cloneSession(oldSessionId);
    await _refreshTaskController();
    await _refresh();
    return clonedSession;
  }

  Future<void> deleteSession(String sessionId) async {
    await ref.read(shoppingServiceProvider).deleteSession(sessionId);
    await _refreshTaskController();
    await _refresh();
  }

  Future<List<ShoppingItem>> itemsForSession(String sessionId) {
    return ref.read(shoppingRepositoryProvider).getItemsBySession(sessionId);
  }

  Future<void> updateItem(ShoppingItem item) async {
    await ref.read(shoppingServiceProvider).updateItem(item);
    await _refreshTaskController();
    await _refresh();
  }

  Future<void> toggleItemCompletion(String itemId) async {
    await ref.read(shoppingServiceProvider).toggleItemCompletion(itemId);
    await _refreshTaskController();
    await _refresh();
  }

  Future<void> setCompleted(ShoppingItem item, bool completed) async {
    await ref.read(shoppingServiceProvider).setCompleted(item, completed);
    await _refreshTaskController();
    await _refresh();
  }

  Future<void> deleteItem(String itemId) async {
    await ref.read(shoppingServiceProvider).deleteItem(itemId);
    await _refreshTaskController();
    await _refresh();
  }

  Future<List<ShoppingItem>> _loadItems() {
    return ref.read(shoppingRepositoryProvider).getItems();
  }

  Future<void> _refresh() async {
    ref.invalidate(shoppingSuggestionsProvider);
    ref.invalidate(shoppingSessionsProvider);
    state = AsyncData(await _loadItems());
    await _refreshLoadedSession();
  }

  Future<void> _refreshLoadedSession() async {
    final loadedSession = _session;
    if (loadedSession == null) {
      return;
    }

    final repository = ref.read(shoppingRepositoryProvider);
    final refreshedSession = await repository.getSessionById(loadedSession.id);
    if (refreshedSession == null) {
      _session = null;
      _sessionItems = const [];
      return;
    }

    _session = refreshedSession;
    _sessionItems = await repository.getItemsBySession(refreshedSession.id);
  }

  Future<void> _refreshTaskController() async {
    ref.invalidate(tasksControllerProvider);
    await ref.read(tasksControllerProvider.future);
  }
}
