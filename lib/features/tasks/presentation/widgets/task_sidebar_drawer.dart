import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings_providers.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../shopping/domain/entities/shopping_session.dart';
import '../../../shopping/presentation/pages/shopping_list_screen.dart';
import '../../../shopping/presentation/providers/shopping_providers.dart';
import '../../domain/entities/task.dart';
import '../pages/stats_page.dart';
import '../pages/task_calendar_page.dart';
import '../pages/tasks_page.dart';
import '../providers/tasks_providers.dart';
import 'task_data_actions.dart';

class TaskSidebarDrawer extends ConsumerStatefulWidget {
  const TaskSidebarDrawer({super.key});

  @override
  ConsumerState<TaskSidebarDrawer> createState() => _TaskSidebarDrawerState();
}

class _TaskSidebarDrawerState extends ConsumerState<TaskSidebarDrawer> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksControllerProvider);
    final shoppingSessionsState = ref.watch(shoppingSessionsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Drawer(
      width: 380,
      child: SafeArea(
        child: tasksState.when(
          data: (tasks) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    'Sidebar',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () {
                      ref.read(appSettingsProvider.notifier).toggleThemeMode();
                    },
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    tooltip: 'Toggle theme',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => _openCalendar(context),
                    icon: const Icon(Icons.calendar_month_outlined),
                    tooltip: 'Open calendar',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Calendar and data tools in one place.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.query_stats_outlined),
                title: const Text('Stats'),
                subtitle: const Text('View streaks and achievements'),
                onTap: () => _openStats(context),
              ),
              const SizedBox(height: 4),
              _ShoppingListsSection(
                sessionsState: shoppingSessionsState,
                onOpenSession: (sessionId) {
                  _openShoppingList(context, sessionId: sessionId);
                },
                onCreateSession: () => _createShoppingSession(context),
              ),
              const SizedBox(height: 16),
              _DataToolsCard(
                onExport: () =>
                    exportTasksJson(context, ref, shareAfterExport: false),
                onShare: () =>
                    exportTasksJson(context, ref, shareAfterExport: true),
                onImport: () => importTasksJson(context, ref),
                onRestore: () => restoreLatestBackup(context, ref),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Sidebar unavailable: $error')),
        ),
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

  void _openCalendar(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TaskCalendarPage()));
  }

  void _openStats(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StatsPage()));
  }

  Future<void> _createShoppingSession(BuildContext context) async {
    final title = await _showCreateShoppingListDialog(context);
    if (!mounted || title == null) {
      return;
    }

    final created = await ref
        .read(shoppingItemsControllerProvider.notifier)
        .createSession(DateUtils.dateOnly(DateTime.now()), title);

    if (!mounted) {
      return;
    }

    _openShoppingList(context, sessionId: created.id);
  }

  void _openShoppingList(BuildContext context, {String? sessionId}) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShoppingListScreen(initialSessionId: sessionId),
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
}

class _ShoppingListsSection extends StatelessWidget {
  const _ShoppingListsSection({
    required this.sessionsState,
    required this.onOpenSession,
    required this.onCreateSession,
  });

  final AsyncValue<List<ShoppingSession>> sessionsState;
  final ValueChanged<String> onOpenSession;
  final VoidCallback onCreateSession;

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Text(
                    'Shopping lists',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCreateSession,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Open any list or create a new one.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            sessionsState.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const Text('No shopping lists yet.');
                }

                return Column(
                  children: [
                    for (final session in sessions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          session.status == ShoppingSessionStatus.completed
                              ? Icons.checklist_rounded
                              : Icons.list_alt_rounded,
                        ),
                        title: Text(session.title),
                        subtitle: Text(_shoppingSessionSubtitle(session)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => onOpenSession(session.id),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Text('Shopping lists unavailable: $error'),
            ),
          ],
        ),
      ),
    );
  }

  String _shoppingSessionSubtitle(ShoppingSession session) {
    final date = DateUtils.dateOnly(session.date.toLocal());
    final status = switch (session.status) {
      ShoppingSessionStatus.active => 'Active',
      ShoppingSessionStatus.completed => 'Completed',
    };
    return '$status · ${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.selectedDate,
    required this.tasks,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<Task> tasks;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmpty = firstOfMonth.weekday - DateTime.monday;
    final taskCounts = <DateTime, int>{};
    for (final task in tasks) {
      final date = DateUtils.dateOnly(task.nextReminderAt);
      if (date.year == month.year && date.month == month.month) {
        taskCounts[date] = (taskCounts[date] ?? 0) + 1;
      }
    }

    final cells = <Widget>[
      for (var i = 0; i < leadingEmpty; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          key: ValueKey('sidebar-day-${month.year}-${month.month}-$day'),
          date: DateTime(month.year, month.month, day),
          selected: DateUtils.isSameDay(
            selectedDate,
            DateTime(month.year, month.month, day),
          ),
          hasTasks: taskCounts.containsKey(
            DateTime(month.year, month.month, day),
          ),
          taskCount: taskCounts[DateTime(month.year, month.month, day)] ?? 0,
          onTap: () => onDaySelected(DateTime(month.year, month.month, day)),
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
  });

  final DateTime date;
  final bool selected;
  final bool hasTasks;
  final int taskCount;
  final VoidCallback onTap;

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

class _DataToolsCard extends StatelessWidget {
  const _DataToolsCard({
    required this.onExport,
    required this.onShare,
    required this.onImport,
    required this.onRestore,
  });

  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onImport;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export JSON'),
            onTap: onExport,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share Export'),
            onTap: onShare,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Import JSON'),
            onTap: onImport,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore Latest Backup'),
            onTap: onRestore,
          ),
        ],
      ),
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
