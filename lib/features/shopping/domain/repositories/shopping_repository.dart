import '../entities/shopping_session.dart';
import '../entities/shopping_item.dart';

abstract class ShoppingRepository {
  Future<ShoppingSession> createSession(DateTime date, String title);
  Future<List<ShoppingSession>> getSessions();
  Future<ShoppingSession?> getSessionById(String id);
  Future<void> updateSession(ShoppingSession session);
  Future<void> deleteSession(String id);

  Future<ShoppingItem> addItem(ShoppingItem item);
  Future<ShoppingItem?> getItemById(String id);
  Future<ShoppingItem> updateItem(ShoppingItem item);
  Future<List<ShoppingItem>> getItems();
  Future<List<ShoppingItem>> getItemsBySession(String sessionId);
  Future<void> updateItemStatus({
    required String itemId,
    required bool isCompleted,
  });
  Future<void> deleteItem(String itemId);
  Future<List<ShoppingItem>> getItemsByTask(String taskId);
}