import 'package:flutter_test/flutter_test.dart';
import 'package:taska/features/shopping/data/models/shopping_item_model.dart';

void main() {
  test('converts shopping items to and from maps', () {
    final item = ShoppingItemModel(
      id: '7f7f5c1d-8c49-4f46-8a1e-4fba9c2f5a11',
      name: 'Milk',
      category: 'Groceries',
      isCompleted: true,
      linkedTaskId: 'task-123',
      sessionId: 'session-123',
      createdAt: DateTime.parse('2026-03-25T10:00:00.000Z'),
    );

    final map = item.toMap();
    final restored = ShoppingItemModel.fromMap(map);

    expect(restored.id, item.id);
    expect(restored.name, item.name);
    expect(restored.category, item.category);
    expect(restored.isCompleted, item.isCompleted);
    expect(restored.linkedTaskId, item.linkedTaskId);
    expect(restored.sessionId, item.sessionId);
    expect(restored.createdAt, item.createdAt);
  });

  test('treats missing linked task id as null', () {
    final restored = ShoppingItemModel.fromMap({
      'id': '7f7f5c1d-8c49-4f46-8a1e-4fba9c2f5a11',
      'name': 'Bread',
      'category': 'Groceries',
      'is_completed': 0,
      'created_at': '2026-03-25T10:00:00.000Z',
    });

    expect(restored.linkedTaskId, isNull);
    expect(restored.isCompleted, isFalse);
  });

  test('treats missing session id as null', () {
    final restored = ShoppingItemModel.fromMap({
      'id': '7f7f5c1d-8c49-4f46-8a1e-4fba9c2f5a11',
      'name': 'Bread',
      'category': 'Groceries',
      'is_completed': 0,
      'created_at': '2026-03-25T10:00:00.000Z',
    });

    expect(restored.sessionId, isNull);
  });
}
