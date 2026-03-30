import 'package:flutter_test/flutter_test.dart';
import 'package:taska/features/shopping/data/models/shopping_session_model.dart';
import 'package:taska/features/shopping/domain/entities/shopping_session.dart';

void main() {
  test('converts shopping sessions to and from maps', () {
    final session = ShoppingSessionModel(
      id: 'd53a2d6d-9d34-4b71-97f7-0e97a3e8cb7a',
      date: DateTime.parse('2026-03-25T00:00:00.000Z'),
      title: 'Weekly groceries',
      status: ShoppingSessionStatus.active,
      createdAt: DateTime.parse('2026-03-25T10:00:00.000Z'),
    );

    final map = session.toMap();
    final restored = ShoppingSessionModel.fromMap(map);

    expect(restored.id, session.id);
    expect(restored.date, session.date);
    expect(restored.title, session.title);
    expect(restored.status, session.status);
    expect(restored.createdAt, session.createdAt);
  });

  test('supports camelCase and snake_case map keys', () {
    final restored = ShoppingSessionModel.fromMap({
      'id': 'd53a2d6d-9d34-4b71-97f7-0e97a3e8cb7a',
      'session_date': '2026-03-25T00:00:00.000Z',
      'title': 'Weekly groceries',
      'status': 'completed',
      'createdAt': '2026-03-25T10:00:00.000Z',
    });

    expect(restored.date, DateTime.parse('2026-03-25T00:00:00.000Z'));
    expect(restored.status, ShoppingSessionStatus.completed);
  });

  test('copyWith preserves unchanged fields', () {
    final session = ShoppingSessionModel(
      id: 'd53a2d6d-9d34-4b71-97f7-0e97a3e8cb7a',
      date: DateTime.parse('2026-03-25T00:00:00.000Z'),
      title: 'Weekly groceries',
      status: ShoppingSessionStatus.active,
      createdAt: DateTime.parse('2026-03-25T10:00:00.000Z'),
    );

    final updated = session.copyWith(status: ShoppingSessionStatus.completed);

    expect(updated.id, session.id);
    expect(updated.date, session.date);
    expect(updated.title, session.title);
    expect(updated.status, ShoppingSessionStatus.completed);
    expect(updated.createdAt, session.createdAt);
  });
}