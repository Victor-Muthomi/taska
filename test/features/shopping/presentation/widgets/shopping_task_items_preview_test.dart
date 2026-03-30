import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taska/features/shopping/domain/entities/shopping_item.dart';
import 'package:taska/features/shopping/presentation/providers/shopping_providers.dart';
import 'package:taska/features/shopping/presentation/widgets/shopping_task_items_preview.dart';
import 'package:taska/features/tasks/domain/entities/task.dart';

void main() {
  testWidgets('linked shopping items can be marked done from the preview', (
    tester,
  ) async {
    final controller = _FakeShoppingItemsController([
      ShoppingItem(
        id: 'milk-1',
        name: 'Milk',
        category: 'Groceries',
        isCompleted: false,
        linkedTaskId: '7',
        createdAt: DateTime(2026, 3, 30, 9),
      ),
      ShoppingItem(
        id: 'coffee-1',
        name: 'Coffee',
        category: 'Groceries',
        isCompleted: false,
        linkedTaskId: '99',
        createdAt: DateTime(2026, 3, 30, 9),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingItemsControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ShoppingTaskItemsPreview(
              taskId: 7,
              taskType: TaskType.shopping,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Coffee'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Milk'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      controller.items.singleWhere((item) => item.id == 'milk-1').isCompleted,
      isTrue,
    );
    final label = tester.widget<Text>(find.text('Milk'));
    expect(label.style?.decoration, TextDecoration.lineThrough);
  });
}

class _FakeShoppingItemsController extends ShoppingItemsController {
  _FakeShoppingItemsController(this.items);

  List<ShoppingItem> items;

  @override
  Future<List<ShoppingItem>> build() async => items;

  @override
  Future<void> setCompleted(ShoppingItem item, bool completed) async {
    items = [
      for (final candidate in items)
        if (candidate.id == item.id)
          candidate.copyWith(isCompleted: completed)
        else
          candidate,
    ];
    state = AsyncData(items);
  }
}
