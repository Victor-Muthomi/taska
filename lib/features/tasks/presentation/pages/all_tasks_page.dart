import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/task.dart';
import '../providers/tasks_providers.dart';
import 'tasks_page.dart';

class AllTasksPage extends ConsumerStatefulWidget {
  const AllTasksPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends ConsumerState<AllTasksPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _TaskSort _sort = _TaskSort.nextReminder;
  bool _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksControllerProvider);

    final body = tasksState.when(
      data: (tasks) => _AllTasksBody(
        tasks: tasks,
        searchQuery: _searchQuery,
        sort: _sort,
        ascending: _ascending,
        onSearchChanged: (value) {
          setState(() => _searchQuery = value);
        },
        onSortChanged: (value) {
          if (value == null) {
            return;
          }
          setState(() => _sort = value);
        },
        onToggleSortDirection: () {
          setState(() => _ascending = !_ascending);
        },
        searchController: _searchController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Tasks unavailable: $error')),
    );

    if (widget.embedded) {
      return SafeArea(child: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('All Tasks')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TasksPage.showTaskFormSheet(context, ref: ref),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Task'),
      ),
    );
  }
}

class _AllTasksBody extends StatelessWidget {
  const _AllTasksBody({
    required this.tasks,
    required this.searchQuery,
    required this.sort,
    required this.ascending,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onToggleSortDirection,
    required this.searchController,
  });

  final List<Task> tasks;
  final String searchQuery;
  final _TaskSort sort;
  final bool ascending;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_TaskSort?> onSortChanged;
  final VoidCallback onToggleSortDirection;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _applyFilters(tasks, searchQuery);
    final sortedTasks = _applySort(filteredTasks, sort, ascending);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('All Tasks', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Search, sort, and update every task from one place.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Search tasks',
            hintText: 'Title, notes, time, status...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<_TaskSort>(
                value: sort,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  border: OutlineInputBorder(),
                ),
                items: _TaskSort.values
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: onSortChanged,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: onToggleSortDirection,
              tooltip: ascending ? 'Sort ascending' : 'Sort descending',
              icon: Icon(
                ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${sortedTasks.length} task${sortedTasks.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        if (sortedTasks.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                searchQuery.isEmpty
                    ? 'No tasks yet. Add one from the Dashboard or this screen.'
                    : 'No tasks match your search.',
              ),
            ),
          )
        else
          for (final task in sortedTasks)
            _AllTaskCard(task: task),
      ],
    );
  }
}

class _AllTaskCard extends ConsumerWidget {
  const _AllTaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => TasksPage.showTaskFormSheet(
          context,
          ref: ref,
          existingTask: task,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _TaskMetaChip(icon: Icons.schedule_outlined, label: task.timeLabel),
                            _TaskMetaChip(icon: Icons.repeat_rounded, label: _repeatLabel(task.repeat)),
                            _TaskMetaChip(icon: Icons.notifications_active_outlined, label: _statusLabel(task.status)),
                            _TaskMetaChip(icon: Icons.wb_sunny_outlined, label: _slotLabel(task.slot)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => TasksPage.showTaskFormSheet(
                      context,
                      ref: ref,
                      existingTask: task,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit task',
                  ),
                ],
              ),
              if (task.notes != null && task.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  task.notes!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Updated ${_formatDateTime(task.updatedAt)} · Next reminder ${_formatDateTime(task.nextReminderAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TaskSort { nextReminder, title, updatedAt, status }

extension on _TaskSort {
  String get label {
    return switch (this) {
      _TaskSort.nextReminder => 'Next reminder',
      _TaskSort.title => 'Title',
      _TaskSort.updatedAt => 'Updated',
      _TaskSort.status => 'Status',
    };
  }
}

List<Task> _applyFilters(List<Task> tasks, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return List<Task>.from(tasks);
  }

  return tasks.where((task) {
    final haystack = [
      task.title,
      task.notes ?? '',
      task.timeLabel,
      _repeatLabel(task.repeat),
      _statusLabel(task.status),
      _slotLabel(task.slot),
    ].join(' ').toLowerCase();
    return haystack.contains(normalized);
  }).toList();
}

List<Task> _applySort(List<Task> tasks, _TaskSort sort, bool ascending) {
  final sorted = List<Task>.from(tasks);
  sorted.sort((left, right) {
    final comparison = switch (sort) {
      _TaskSort.nextReminder => left.nextReminderAt.compareTo(right.nextReminderAt),
      _TaskSort.title => left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      _TaskSort.updatedAt => left.updatedAt.compareTo(right.updatedAt),
      _TaskSort.status => left.status.index.compareTo(right.status.index),
    };
    return ascending ? comparison : -comparison;
  });
  return sorted;
}

String _slotLabel(TaskSlot slot) {
  return switch (slot) {
    TaskSlot.morning => 'Morning',
    TaskSlot.afternoon => 'Afternoon',
    TaskSlot.evening => 'Evening',
  };
}

String _repeatLabel(TaskRepeat repeat) {
  return switch (repeat) {
    TaskRepeat.none => 'No repeat',
    TaskRepeat.daily => 'Daily',
    TaskRepeat.weekdays => 'Weekdays',
    TaskRepeat.weekly => 'Weekly',
  };
}

String _statusLabel(TaskReminderStatus status) {
  return switch (status) {
    TaskReminderStatus.pending => 'Pending',
    TaskReminderStatus.completed => 'Done',
    TaskReminderStatus.snoozed => 'Snoozed',
    TaskReminderStatus.ignored => 'Ignored',
  };
}

String _formatDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.month}/${value.day} $hour:$minute';
}

class _TaskMetaChip extends StatelessWidget {
  const _TaskMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}