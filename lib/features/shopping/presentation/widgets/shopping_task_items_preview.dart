import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tasks/domain/entities/task.dart';
import '../providers/shopping_providers.dart';

class ShoppingTaskItemsPreview extends ConsumerWidget {
  const ShoppingTaskItemsPreview({
    super.key,
    required this.taskId,
    required this.taskType,
  });

  final int? taskId;
  final TaskType taskType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (taskType != TaskType.shopping || taskId == null) {
      return const SizedBox.shrink();
    }

    final itemsState = ref.watch(shoppingItemsControllerProvider);
    return itemsState.when(
      data: (items) {
        final linkedItems = items
            .where((item) => item.linkedTaskId == taskId.toString())
            .toList();
        if (linkedItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shopping items',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in linkedItems)
                    Chip(
                      avatar: Icon(
                        item.isCompleted
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      label: Text(item.name),
                    ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
