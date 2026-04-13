import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shopping/presentation/pages/shopping_list_screen.dart';
import '../../../shopping/presentation/providers/shopping_providers.dart';
import '../../../shopping/presentation/widgets/shopping_task_items_preview.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_providers.dart';
import '../widgets/task_calendar_utils.dart';
import 'tasks_page.dart';

class TaskCalendarPage extends ConsumerStatefulWidget {
  const TaskCalendarPage({super.key});

  @override
  ConsumerState<TaskCalendarPage> createState() => _TaskCalendarPageState();
}

class _TaskCalendarPageState extends ConsumerState<TaskCalendarPage> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: tasksState.when(
        data: (tasks) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Touch and hold a day to add or update tasks for that date.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _CalendarMonthCard(
              month: _visibleMonth,
              selectedDate: _selectedDate,
              tasks: tasks,
              onPreviousMonth: _previousMonth,
              onNextMonth: _nextMonth,
              onDaySelected: (date) {
                setState(() {
                  _selectedDate = DateUtils.dateOnly(date);
                  _visibleMonth = DateTime(date.year, date.month);
                });
              },
              onDayLongPressed: (date) => _openDayActions(
                context,
                tasksForDate(tasks, date),
                date,
              ),
            ),
            const SizedBox(height: 16),
            _SelectedDateTasksCard(
              date: _selectedDate,
              tasks: tasksForDate(tasks, _selectedDate),
              onEditTask: (task) {
                TasksPage.showTaskFormSheet(
                  context,
                  ref: ref,
                  existingTask: task,
                  scheduledFor: _selectedDate,
                );
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Calendar unavailable: $error')),
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  Future<void> _openDayActions(
    BuildContext context,
    List<Task> dayTasks,
    DateTime date,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _DayActionsSheet(
              date: date,
              tasks: dayTasks,
              onAddTask: () {
                Navigator.of(sheetContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) {
                    return;
                  }
                  TasksPage.showTaskFormSheet(
                    context,
                    ref: ref,
                    scheduledFor: date,
                    initialTitle: 'Event',
                  );
                });
              },
              onAddEvent: () {
                Navigator.of(sheetContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) {
                    return;
                  }
                  TasksPage.showTaskFormSheet(
                    context,
                    ref: ref,
                    scheduledFor: date,
                  );
                });
              },
              onAddShoppingList: () {
                Navigator.of(sheetContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!context.mounted) {
                    return;
                  }

                  final title = await _showCreateShoppingListDialog(
                    context,
                    date,
                  );
                  if (title == null || !context.mounted) {
                    return;
                  }

                  final createdSession = await ref
                      .read(shoppingItemsControllerProvider.notifier)
                      .createSession(DateUtils.dateOnly(date), title);
                  if (!context.mounted) {
                    return;
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ShoppingListScreen(initialSessionId: createdSession.id),
                    ),
                  );
                });
              },
              onEditTask: (task) {
                Navigator.of(sheetContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) {
                    return;
                  }
                  TasksPage.showTaskFormSheet(
                    context,
                    ref: ref,
                    existingTask: task,
                    scheduledFor: date,
                  );
                });
              },
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showCreateShoppingListDialog(
    BuildContext context,
    DateTime date,
  ) async {
    final controller = TextEditingController();
    final normalizedDate = DateUtils.dateOnly(date);
    final fallbackTitle =
        'Shopping List ${normalizedDate.year.toString().padLeft(4, '0')}-${normalizedDate.month.toString().padLeft(2, '0')}-${normalizedDate.day.toString().padLeft(2, '0')}';

    try {
      return showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add shopping list'),
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
                ).pop(value.isEmpty ? fallbackTitle : value);
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
                  ).pop(value.isEmpty ? fallbackTitle : value);
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
}

class _CalendarMonthCard extends StatelessWidget {
  const _CalendarMonthCard({
    required this.month,
    required this.selectedDate,
    required this.tasks,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
    required this.onDayLongPressed,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<Task> tasks;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onDayLongPressed;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmpty = firstOfMonth.weekday - DateTime.monday;
    final taskCounts = taskCountsForMonth(tasks, month);

    final cells = <Widget>[
      for (var i = 0; i < leadingEmpty; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          key: ValueKey('calendar-day-${month.year}-${month.month}-$day'),
          date: DateTime(month.year, month.month, day),
          selected: DateUtils.isSameDay(
            selectedDate,
            DateTime(month.year, month.month, day),
          ),
          hasTasks: taskCounts.containsKey(DateTime(month.year, month.month, day)),
          taskCount: taskCounts[DateTime(month.year, month.month, day)] ?? 0,
          onTap: () => onDaySelected(DateTime(month.year, month.month, day)),
          onLongPress: () => onDayLongPressed(DateTime(month.year, month.month, day)),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    MaterialLocalizations.of(context).formatMonthYear(month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
              children: cells,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.date,
    required this.selected,
    required this.hasTasks,
    required this.taskCount,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime date;
  final bool selected;
  final bool hasTasks;
  final int taskCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(DateTime.now(), date);
    final theme = Theme.of(context);
    final background = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isToday
                ? Border.all(color: theme.colorScheme.primary, width: 1.2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    date.day.toString(),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                if (hasTasks)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        taskCount.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayActionsSheet extends StatelessWidget {
  const _DayActionsSheet({
    required this.date,
    required this.tasks,
    required this.onAddTask,
    required this.onAddEvent,
    required this.onAddShoppingList,
    required this.onEditTask,
  });

  final DateTime date;
  final List<Task> tasks;
  final VoidCallback onAddTask;
  final VoidCallback onAddEvent;
  final VoidCallback onAddShoppingList;
  final ValueChanged<Task> onEditTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MaterialLocalizations.of(context).formatMediumDate(date),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Add a task, event, or shopping list for this day.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onAddTask,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Add task for this day'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAddEvent,
            icon: const Icon(Icons.event_outlined),
            label: const Text('Add event'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAddShoppingList,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('Add shopping list'),
          ),
        ),
        const SizedBox(height: 16),
        if (tasks.isEmpty)
          Text(
            'No tasks scheduled for this day.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(task.title),
              subtitle: Text('${task.timeLabel} · ${_statusLabel(task.status)}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => onEditTask(task),
              ),
            ),
      ],
    );
  }
}

class _SelectedDateTasksCard extends StatelessWidget {
  const _SelectedDateTasksCard({
    required this.date,
    required this.tasks,
    required this.onEditTask,
  });

  final DateTime date;
  final List<Task> tasks;
  final ValueChanged<Task> onEditTask;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tasks for ${date.month}/${date.day}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              Text(
                'No tasks scheduled for this day.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (final task in tasks)
                Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(task.title),
                      subtitle: Text(
                        '${task.timeLabel} · ${_statusLabel(task.status)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => onEditTask(task),
                      ),
                    ),
                    ShoppingTaskItemsPreview(
                      taskId: task.id,
                      taskType: task.type,
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(TaskReminderStatus status) {
  return switch (status) {
    TaskReminderStatus.pending => 'Pending',
    TaskReminderStatus.completed => 'Done',
    TaskReminderStatus.snoozed => 'Snoozed',
    TaskReminderStatus.ignored => 'Ignored',
  };
}