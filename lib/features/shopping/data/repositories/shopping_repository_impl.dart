import 'dart:math';

import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_session.dart';
import '../../domain/repositories/shopping_repository.dart';
import '../datasources/shopping_local_data_source.dart';
import '../models/shopping_item_model.dart';
import '../models/shopping_session_model.dart';

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

class ShoppingRepositoryImpl implements ShoppingRepository {
  ShoppingRepositoryImpl({required ShoppingLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  final ShoppingLocalDataSource _localDataSource;

  @override
  Future<ShoppingSession> createSession(DateTime date, String title) async {
    final session = ShoppingSessionModel(
      id: _createUuid(),
      date: date,
      title: title,
      status: ShoppingSessionStatus.active,
      createdAt: DateTime.now().toUtc(),
    );
    return _localDataSource.createSession(session);
  }

  @override
  Future<List<ShoppingSession>> getSessions() {
    return _localDataSource.getSessions();
  }

  @override
  Future<ShoppingSession?> getSessionById(String id) {
    return _localDataSource.getSessionById(id);
  }

  @override
  Future<void> updateSession(ShoppingSession session) {
    return _localDataSource.updateSession(ShoppingSessionModel.fromEntity(session));
  }

  @override
  Future<void> deleteSession(String id) {
    return _localDataSource.deleteSession(id);
  }

  @override
  Future<ShoppingItem> addItem(ShoppingItem item) {
    return _localDataSource.addItem(ShoppingItemModel.fromEntity(item));
  }

  @override
  Future<ShoppingItem?> getItemById(String id) {
    return _localDataSource.getItemById(id);
  }

  @override
  Future<ShoppingItem> updateItem(ShoppingItem item) {
    return _localDataSource.updateItem(ShoppingItemModel.fromEntity(item));
  }

  @override
  Future<List<ShoppingItem>> getItems() {
    return _localDataSource.getItems();
  }

  @override
  Future<List<ShoppingItem>> getItemsBySession(String sessionId) {
    return _localDataSource.getItemsBySession(sessionId);
  }

  @override
  Future<void> updateItemStatus({
    required String itemId,
    required bool isCompleted,
  }) {
    return _localDataSource.updateItemStatus(
      itemId: itemId,
      isCompleted: isCompleted,
    );
  }

  @override
  Future<void> deleteItem(String itemId) {
    return _localDataSource.deleteItem(itemId);
  }

  @override
  Future<List<ShoppingItem>> getItemsByTask(String taskId) {
    return _localDataSource.getItemsByTask(taskId);
  }
}