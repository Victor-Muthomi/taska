import 'package:flutter/material.dart';

import '../../domain/entities/shopping_item.dart';

class SuggestedItemsWidget extends StatelessWidget {
  const SuggestedItemsWidget({
    super.key,
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  final List<ShoppingItem> suggestions;
  final ValueChanged<ShoppingItem> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Smart suggestions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tap once to reuse items the app has seen often.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text('${item.name} · ${item.category}'),
                    onPressed: () => onSuggestionSelected(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}