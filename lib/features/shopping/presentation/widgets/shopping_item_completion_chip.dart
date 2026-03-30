import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/shopping_item.dart';
import '../providers/shopping_providers.dart';

class ShoppingItemCompletionChip extends ConsumerStatefulWidget {
  const ShoppingItemCompletionChip({super.key, required this.item});

  final ShoppingItem item;

  @override
  ConsumerState<ShoppingItemCompletionChip> createState() =>
      _ShoppingItemCompletionChipState();
}

class _ShoppingItemCompletionChipState
    extends ConsumerState<ShoppingItemCompletionChip> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
    );

    return FilterChip(
      selected: item.isCompleted,
      showCheckmark: false,
      avatar: _isUpdating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              item.isCompleted
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              size: 18,
            ),
      label: Text(item.name, style: labelStyle),
      onSelected: _isUpdating ? null : _handleSelected,
    );
  }

  void _handleSelected(bool selected) {
    setState(() => _isUpdating = true);
    unawaited(_toggleCompletion(selected));
  }

  Future<void> _toggleCompletion(bool selected) async {
    try {
      await ref
          .read(shoppingItemsControllerProvider.notifier)
          .setCompleted(widget.item, selected);
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }
}
