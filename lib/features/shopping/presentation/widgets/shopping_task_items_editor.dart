import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/shopping_item.dart';
import '../providers/shopping_providers.dart';
import 'shopping_item_completion_chip.dart';

class ShoppingTaskItemsEditor extends ConsumerStatefulWidget {
  const ShoppingTaskItemsEditor({
    super.key,
    required this.taskId,
    required this.pendingItemNames,
    required this.onQueueItem,
    required this.onRemoveQueuedItem,
    required this.onLinkItem,
    this.enabled = true,
  });

  final String? taskId;
  final List<String> pendingItemNames;
  final ValueChanged<String> onQueueItem;
  final ValueChanged<String> onRemoveQueuedItem;
  final Future<void> Function(String name) onLinkItem;
  final bool enabled;

  @override
  ConsumerState<ShoppingTaskItemsEditor> createState() =>
      _ShoppingTaskItemsEditorState();
}

class _ShoppingTaskItemsEditorState
    extends ConsumerState<ShoppingTaskItemsEditor> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shoppingItemsState = ref.watch(shoppingItemsControllerProvider);
    final linkedItems = shoppingItemsState.maybeWhen(
      data: (items) {
        final taskId = widget.taskId;
        if (taskId == null) {
          return const <ShoppingItem>[];
        }
        return items.where((item) => item.linkedTaskId == taskId).toList();
      },
      orElse: () => const <ShoppingItem>[],
    );
    final hasExistingTask = widget.taskId != null;
    final pendingItems = widget.pendingItemNames;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Shopping items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasExistingTask
                  ? 'Add items here and they will stay linked to this shopping task.'
                  : 'Add items now and Taska will link them after you save the task.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: widget.enabled && !_isSubmitting,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Item',
                      hintText: 'Milk, bread, coffee...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: widget.enabled && !_isSubmitting ? _submit : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(hasExistingTask ? 'Link' : 'Queue'),
                ),
              ],
            ),
            if (!hasExistingTask) ...[
              const SizedBox(height: 10),
              Text(
                'Pending items are attached as soon as you save the task.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (pendingItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                hasExistingTask ? 'Queued items' : 'Pending items',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in pendingItems)
                    InputChip(
                      label: Text(item),
                      onDeleted: widget.enabled && !_isSubmitting
                          ? () => widget.onRemoveQueuedItem(item)
                          : null,
                    ),
                ],
              ),
            ],
            if (linkedItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Linked now', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in linkedItems)
                    ShoppingItemCompletionChip(item: item),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (widget.taskId == null) {
        widget.onQueueItem(value);
      } else {
        await widget.onLinkItem(value);
      }
      _controller.clear();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
