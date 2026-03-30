import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taska/core/database/app_database.dart';
import 'package:taska/features/shopping/data/datasources/shopping_local_data_source.dart';
import 'package:taska/features/shopping/data/repositories/shopping_repository_impl.dart';
import 'package:taska/features/shopping/domain/entities/shopping_item.dart';
import 'package:taska/features/shopping/domain/entities/shopping_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late ShoppingRepositoryImpl repository;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            final dir = await Directory.systemTemp.createTemp(
              'taska_shopping_repo_docs',
            );
            return dir.path;
          }
          return null;
        });
    repository = ShoppingRepositoryImpl(
      localDataSource: ShoppingLocalDataSource(
        databaseHelper: AppDatabase.instance,
      ),
    );
  });

  setUp(() async {
    final db = await AppDatabase.instance.database;
    await db.delete('shopping_items');
    await db.delete('shopping_sessions');
  });

  test('adds, updates, queries, and deletes shopping items', () async {
    final created = await repository.addItem(
      ShoppingItem(
        id: 'item-1',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: false,
        linkedTaskId: 'task-42',
        createdAt: DateTime(2026, 3, 25, 9),
      ),
    );

    expect(created.id, 'item-1');

    final allItems = await repository.getItems();
    expect(allItems, hasLength(1));
    expect(allItems.single.name, 'Milk');

    final linkedItems = await repository.getItemsByTask('task-42');
    expect(linkedItems, hasLength(1));

    await repository.updateItemStatus(itemId: 'item-1', isCompleted: true);
    final updated = await repository.getItems();
    expect(updated.single.isCompleted, isTrue);

    await repository.deleteItem('item-1');
    expect(await repository.getItems(), isEmpty);
  });

  test('creates, updates, and deletes empty shopping sessions', () async {
    final created = await repository.createSession(
      DateTime(2026, 3, 25),
      'Weekly groceries',
    );

    final sessions = await repository.getSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.id, created.id);

    final loaded = await repository.getSessionById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.title, 'Weekly groceries');
    expect(loaded.status, ShoppingSessionStatus.active);

    await repository.updateSession(
      loaded.copyWith(title: 'Weekend groceries'),
    );
    final updated = await repository.getSessionById(created.id);
    expect(updated!.title, 'Weekend groceries');

    await repository.deleteSession(created.id);
    expect(await repository.getSessionById(created.id), isNull);
  });

  test('refuses to delete non-empty shopping sessions', () async {
    final session = await repository.createSession(
      DateTime(2026, 3, 25),
      'Weekly groceries',
    );

    await repository.addItem(
      ShoppingItem(
        id: 'item-2',
        name: 'Bread',
        category: 'Groceries',
        isCompleted: false,
        sessionId: session.id,
        createdAt: DateTime(2026, 3, 25, 10),
      ),
    );

    expect(
      () => repository.deleteSession(session.id),
      throwsA(isA<StateError>()),
    );
  });
}