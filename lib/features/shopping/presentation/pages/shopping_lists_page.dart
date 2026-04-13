import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/shopping_session.dart';
import '../providers/shopping_providers.dart';
import 'shopping_list_screen.dart';

class ShoppingListsPage extends ConsumerWidget {
  const ShoppingListsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsState = ref.watch(shoppingSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Lists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createSession(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New list'),
      ),
      body: SafeArea(
        child: sessionsState.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No shopping lists yet. Create your first list.'),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Dismissible(
                  key: ValueKey('shopping-session-${session.id}'),
                  direction: DismissDirection.startToEnd,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    final shouldDelete =
                        await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: const Text('Delete shopping list'),
                              content: Text(
                                'Delete "${session.title}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        ) ??
                        false;

                    if (!shouldDelete) {
                      return false;
                    }

                    try {
                      await ref
                          .read(shoppingItemsControllerProvider.notifier)
                          .deleteSession(session.id);
                      return true;
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_deleteErrorMessage(error))),
                        );
                      }
                      return false;
                    }
                  },
                  onDismissed: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted "${session.title}"')),
                    );
                  },
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        session.status == ShoppingSessionStatus.completed
                            ? Icons.checklist_rounded
                            : Icons.list_alt_rounded,
                      ),
                      title: Text(session.title),
                      subtitle: Text(_shoppingSessionSubtitle(session)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ShoppingListScreen(initialSessionId: session.id),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Shopping lists unavailable: $error'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createSession(BuildContext context, WidgetRef ref) async {
    final title = await _showCreateShoppingListDialog(context);
    if (title == null || !context.mounted) {
      return;
    }

    final created = await ref
        .read(shoppingItemsControllerProvider.notifier)
        .createSession(DateUtils.dateOnly(DateTime.now()), title);

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShoppingListScreen(initialSessionId: created.id),
      ),
    );
  }

  Future<String?> _showCreateShoppingListDialog(BuildContext context) async {
    final controller = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('New shopping list'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'List name',
                hintText: 'Weekend groceries',
              ),
              onSubmitted: (_) {
                final value = controller.text.trim();
                Navigator.of(
                  dialogContext,
                ).pop(value.isEmpty ? 'Shopping List' : value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  Navigator.of(
                    dialogContext,
                  ).pop(value.isEmpty ? 'Shopping List' : value);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  String _shoppingSessionSubtitle(ShoppingSession session) {
    final date = DateUtils.dateOnly(session.date.toLocal());
    final status = switch (session.status) {
      ShoppingSessionStatus.active => 'Active',
      ShoppingSessionStatus.completed => 'Completed',
    };
    return '$status · ${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _deleteErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('active shopping list')) {
      return 'This list is active. Mark it completed before deleting.';
    }
    if (message.contains('still has items')) {
      return 'Remove all items before deleting this list.';
    }
    return 'Could not delete this shopping list.';
  }
}