import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_session.dart';

abstract class ShoppingSessionViewContract {
  ShoppingSession get session;
  List<ShoppingItem> get items;
}

abstract class ActiveShoppingSessionContract
    implements ShoppingSessionViewContract {
  Future<void> updateSession(ShoppingSession session);
  Future<void> updateItem(ShoppingItem item);
  Future<void> toggleItemCompletion(String itemId);
  Future<void> deleteItem(String itemId);
  Future<void> deleteSession(String sessionId);
}

abstract class ShoppingSessionCloneAction {
  Future<ShoppingSession> cloneSession(String sessionId);
}