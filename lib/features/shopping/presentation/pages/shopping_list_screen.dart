import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shopping/shopping_service_providers.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_session.dart';
import '../providers/shopping_providers.dart';
import '../widgets/add_item_input.dart';
import '../widgets/suggested_items_widget.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  ShoppingSession? _bootstrapSession;
  bool _isBootstrapping = true;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bootstrapCurrentSession();
      }
    });
  }

  Future<void> _bootstrapCurrentSession() async {
    try {
      final repository = ref.read(shoppingRepositoryProvider);
      final controller = ref.read(shoppingItemsControllerProvider.notifier);
      final sessions = await repository.getSessions();
      final today = DateUtils.dateOnly(DateTime.now());

      ShoppingSession? selectedSession;

      for (final session in sessions) {
        if (DateUtils.dateOnly(session.date) == today &&
            session.status == ShoppingSessionStatus.active) {
          selectedSession = session;
          break;
        }
      }

      if (selectedSession == null) {
        for (final session in sessions) {
          if (session.status == ShoppingSessionStatus.active) {
            selectedSession = session;
            break;
          }
        }
      }

      selectedSession ??= sessions.isNotEmpty ? sessions.first : null;

      if (selectedSession == null) {
        selectedSession = await controller.createSession(today, 'Shopping List');
      } else {
        await controller.loadSession(selectedSession.id);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapSession = selectedSession;
        _bootstrapError = null;
        _isBootstrapping = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapError = error.toString();
        _isBootstrapping = false;
      });
    }
  }

  ShoppingSession? _currentSession(ShoppingItemsController controller) {
    try {
      return controller.session;
    } on StateError {
      return _bootstrapSession;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(shoppingItemsControllerProvider);
    final suggestionsState = ref.watch(shoppingSuggestionsProvider);
    final controller = ref.read(shoppingItemsControllerProvider.notifier);
    final session = _currentSession(controller);

    if (_isBootstrapping) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shopping List')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_bootstrapError != null && session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shopping List')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Shopping unavailable: $_bootstrapError'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _bootstrapCurrentSession,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shopping List')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final items = controller.items;
    final categories = _sortedCategories(items);

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(shoppingItemsControllerProvider);
            ref.invalidate(shoppingSuggestionsProvider);
            await _bootstrapCurrentSession();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                session.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _sessionSummary(session),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _SessionHeader(
                session: session,
                onEditDate: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateUtils.dateOnly(session.date),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate == null) {
                    return;
                  }

                  await controller.updateSession(
                    session.copyWith(
                      date: DateUtils.dateOnly(pickedDate),
                    ),
                  );
                },
                onClone: () async {
                  await controller.cloneSession(session.id);
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 16),
              AddItemInput(
                categoryOptions: categories,
                onAdd: (name, category) {
                  return controller.addItem(name: name, category: category);
                },
              ),
              const SizedBox(height: 12),
              suggestionsState.when(
                data: (suggestions) => SuggestedItemsWidget(
                  suggestions: suggestions,
                  onSuggestionSelected: (item) {
                    controller.addSuggestedItem(item);
                  },
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const _EmptyShoppingState()
              else
                for (final category in categories)
                  _CategorySection(
                    category: category,
                    items: items
                        .where(
                          (item) => _categoryLabel(item.category) == category,
                        )
                        .toList(),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _sortedCategories(List<ShoppingItem> items) {
    final categories = items.map((item) => _categoryLabel(item.category)).toSet().toList();
    categories.sort((a, b) {
      if (a == 'General') {
        return -1;
      }
      if (b == 'General') {
        return 1;
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return categories;
  }

  String _categoryLabel(String category) {
    final trimmed = category.trim();
    return trimmed.isEmpty ? 'General' : trimmed;
  }

  String _sessionSummary(ShoppingSession session) {
    return 'Session for ${_formatDate(session.date)}';
  }

  String _formatDate(DateTime date) {
    final local = DateUtils.dateOnly(date.toLocal());
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.session,
    required this.onEditDate,
    required this.onClone,
  });

  final ShoppingSession session;
  final VoidCallback? onEditDate;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: const Text('Active'),
                  backgroundColor: colorScheme.primaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date ${DateUtils.dateOnly(session.date).toIso8601String().split('T').first}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (onEditDate != null)
                  OutlinedButton.icon(
                    onPressed: onEditDate,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Change date'),
                  ),
                OutlinedButton.icon(
                  onPressed: onClone,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Clone session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.items,
  });

  final String category;
  final List<ShoppingItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  category,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items) _ShoppingItemTile(item: item),
          ],
        ),
      ),
    );
  }
}

class _ShoppingItemTile extends ConsumerWidget {
  const _ShoppingItemTile({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
      color: item.isCompleted ? Theme.of(context).colorScheme.outline : null,
    );

    return Dismissible(
      key: ValueKey('shopping-item-${item.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) async {
        await ref.read(shoppingItemsControllerProvider.notifier).deleteItem(item.id);
      },
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        value: item.isCompleted,
        onChanged: (value) {
          ref
              .read(shoppingItemsControllerProvider.notifier)
              .setCompleted(item, value ?? false);
        },
        title: Text(item.name, style: titleStyle),
        subtitle: item.linkedTaskId == null
            ? Text(
                item.category,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : Text(
                'Linked to task ${item.linkedTaskId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
    );
  }
}

class _EmptyShoppingState extends StatelessWidget {
  const _EmptyShoppingState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No shopping items yet. Add one above or tap a suggestion.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}