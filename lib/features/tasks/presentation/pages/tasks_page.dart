import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/behavior_analytics.dart';
import '../../../../core/analytics/behavior_analytics_providers.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/notifications/notification_logic.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/scheduling/slot_schedule.dart';
import '../../../../core/settings/app_settings_providers.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_providers.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key, this.embedded = false});

  final bool embedded;

  static Future<void> showTaskFormSheet(
    BuildContext context, {
    WidgetRef? ref,
    Task? existingTask,
    DateTime? scheduledFor,
  }) async {
    if (ref != null) {
      final page = TasksPage();
      await page._showTaskFormSheet(
        context,
        ref,
        existingTask: existingTask,
        scheduledFor: scheduledFor,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, bottomSheetRef, _) {
            return _TaskFormSheet(
              existingTask: existingTask,
              scheduledFor: scheduledFor,
              ref: bottomSheetRef,
              initialScheduledFor:
                  scheduledFor ?? existingTask?.nextReminderAt ?? DateTime.now(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksControllerProvider);
    final behaviorInsight = ref.watch(behaviorInsightProvider);
    final settings = ref.watch(appSettingsProvider);

    ref.listen(notificationEventsProvider, (previous, next) {
      next.whenData((event) async {
        await ref
            .read(tasksControllerProvider.notifier)
            .handleNotificationEvent(event);

        if (!context.mounted) {
          return;
        }

        final message = switch (event.type) {
          NotificationEventType.opened =>
            'Reminder opened for task #${event.taskId}',
          NotificationEventType.snoozed =>
            'Reminder snoozed for ${settings.defaultSnoozeMinutes} minutes',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      });
    });

    final body = tasksState.when(
      data: (tasks) =>
          _DashboardView(tasks: tasks, behaviorInsight: behaviorInsight),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load tasks: $error')),
    );

    if (embedded) {
      return SafeArea(child: body);
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskFormSheet(context, ref),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Task'),
      ),
      body: SafeArea(child: body),
    );
  }

  Future<void> _showTaskFormSheet(
    BuildContext context,
    WidgetRef ref, {
    Task? existingTask,
    DateTime? scheduledFor,
  }) async {
    final titleController = TextEditingController(
      text: existingTask?.title ?? '',
    );
    final notesController = TextEditingController(
      text: existingTask?.notes ?? '',
    );
    final timeController = TextEditingController(
      text: existingTask?.timeLabel ?? '08:00',
    );
    final initialScheduledFor =
        scheduledFor ?? existingTask?.nextReminderAt ?? DateTime.now();
    var selectedSlot = existingTask?.slot ?? TaskSlot.morning;
    var selectedRepeat = existingTask?.repeat ?? TaskRepeat.none;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TaskFormSheet(
        existingTask: existingTask,
        scheduledFor: scheduledFor,
        ref: ref,
        titleController: titleController,
        notesController: notesController,
        timeController: timeController,
        initialSlot: selectedSlot,
        initialRepeat: selectedRepeat,
        initialScheduledFor: initialScheduledFor,
      ),
    );
  }
}

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({
    required this.ref,
    this.existingTask,
    this.scheduledFor,
    this.titleController,
    this.notesController,
    this.timeController,
    this.initialSlot = TaskSlot.morning,
    this.initialRepeat = TaskRepeat.none,
    required this.initialScheduledFor,
  });

  final WidgetRef ref;
  final Task? existingTask;
  final DateTime? scheduledFor;
  final TextEditingController? titleController;
  final TextEditingController? notesController;
  final TextEditingController? timeController;
  final TaskSlot initialSlot;
  final TaskRepeat initialRepeat;
  final DateTime initialScheduledFor;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late TaskSlot _selectedSlot;
  late TaskRepeat _selectedRepeat;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        widget.titleController ??
        TextEditingController(text: widget.existingTask?.title ?? '');
    _notesController =
        widget.notesController ??
        TextEditingController(text: widget.existingTask?.notes ?? '');
    _timeController =
        widget.timeController ??
        TextEditingController(text: widget.existingTask?.timeLabel ?? '08:00');
    _selectedSlot = widget.initialSlot;
    _selectedRepeat = widget.initialRepeat;
    _selectedDate = DateUtils.dateOnly(widget.initialScheduledFor);
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
  }

  @override
  void dispose() {
    if (widget.titleController == null) {
      _titleController.dispose();
    }
    if (widget.notesController == null) {
      _notesController.dispose();
    }
    _dateController.dispose();
    if (widget.timeController == null) {
      _timeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTask != null;
    final affectsFutureOccurrences =
        isEditing && _selectedRepeat != TaskRepeat.none;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Task' : 'Add Task',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                isEditing
                    ? 'Update the task details and Taska will re-plan the next reminder window.'
                    : 'Create a task inside the time window when you actually want to handle it.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (affectsFutureOccurrences) ...[
                const SizedBox(height: 16),
                _FormInfoBanner(
                  icon: Icons.repeat_rounded,
                  message:
                      'This is a recurring task. Changes here update its upcoming reminders, not just one reminder.',
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Drink water, call client, review notes...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final title = value?.trim() ?? '';
                  if (title.isEmpty) {
                    return 'Add a short task title.';
                  }
                  if (title.length < 3) {
                    return 'Use at least 3 characters so the task is easy to spot.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  helperText: 'Pick the day this task should start on.',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) {
                    return;
                  }

                  setState(() {
                    _selectedDate = DateUtils.dateOnly(picked);
                    _dateController.text = _formatDate(_selectedDate);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timeController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Time inside slot',
                  helperText:
                      'Taska keeps this time inside the ${_slotLabel(_selectedSlot).toLowerCase()} window.',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.schedule_outlined),
                ),
                validator: (value) {
                  return _parseTimeLabel(value ?? '') == null
                      ? 'Pick a valid time for this task.'
                      : null;
                },
                onTap: () async {
                  final now = TimeOfDay.now();
                  final initialTime =
                      _parseTimeLabel(_timeController.text) ?? now;
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: initialTime,
                  );
                  if (picked == null) {
                    return;
                  }
                  setState(() {
                    _timeController.text = SlotSchedule.normalizeTimeForSlot(
                      _formatTimeOfDay(picked),
                      _selectedSlot,
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskSlot>(
                initialValue: _selectedSlot,
                decoration: InputDecoration(
                  labelText: 'Slot',
                  helperText:
                      'Window: ${SlotSchedule.labelForWindow(SlotSchedule.windows[_selectedSlot]!)}',
                  border: const OutlineInputBorder(),
                ),
                items: TaskSlot.values
                    .map(
                      (slot) => DropdownMenuItem(
                        value: slot,
                        child: Text(_slotLabel(slot)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedSlot = value;
                    _timeController.text = SlotSchedule.normalizeTimeForSlot(
                      _timeController.text,
                      value,
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskRepeat>(
                initialValue: _selectedRepeat,
                decoration: const InputDecoration(
                  labelText: 'Repeat',
                  helperText:
                      'Use repeat for routines you want Taska to keep planning automatically.',
                  border: OutlineInputBorder(),
                ),
                items: TaskRepeat.values
                    .map(
                      (repeat) => DropdownMenuItem(
                        value: repeat,
                        child: Text(_repeatLabel(repeat)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _selectedRepeat = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  helperText:
                      'Optional context to make the reminder more useful.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : () => _submit(context),
                  child: Text(
                    _isSaving
                        ? 'Saving...'
                        : isEditing
                        ? 'Update Task'
                        : 'Save Task',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final title = _titleController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    try {
      if (widget.existingTask == null) {
        await widget.ref
            .read(tasksControllerProvider.notifier)
            .addTask(
              title: title,
              notes: notes,
              timeLabel: _timeController.text,
              slot: _selectedSlot,
              repeat: _selectedRepeat,
              scheduledFor: _selectedDate,
            );
      } else {
        await widget.ref
            .read(tasksControllerProvider.notifier)
            .updateTaskDetails(
              task: widget.existingTask!,
              title: title,
              notes: notes,
              timeLabel: _timeController.text,
              slot: _selectedSlot,
              repeat: _selectedRepeat,
              scheduledFor: _selectedDate,
            );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingTask == null
                  ? 'Task saved to ${_slotLabel(_selectedSlot).toLowerCase()}.'
                  : 'Task updated and future reminders refreshed.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

String _formatDate(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _FormInfoBanner extends StatelessWidget {
  const _FormInfoBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.tasks, required this.behaviorInsight});

  final List<Task> tasks;
  final AsyncValue<BehaviorInsight> behaviorInsight;

  @override
  Widget build(BuildContext context) {
    final todaysTasks = tasks.where(_isTodayTask).toList();
    final grouped = {
      for (final slot in TaskSlot.values)
        slot: todaysTasks.where((task) => task.slot == slot).toList(),
    };

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage your day',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Stop missing time windows, not just exact clock times.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.appName,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: _DashboardSummary(tasks: todaysTasks),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _BehaviorInsights(behaviorInsight: behaviorInsight),
                ),
              ],
            ),
          ),
        ),
        if (todaysTasks.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _EmptyTasksState(),
            ),
          )
        else
          for (final slot in TaskSlot.values)
            SliverToBoxAdapter(
              child: _TaskSlotSection(
                slot: slot,
                tasks: grouped[slot] ?? const [],
              ),
            ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }
}

class _BehaviorInsights extends StatelessWidget {
  const _BehaviorInsights({required this.behaviorInsight});

  final AsyncValue<BehaviorInsight> behaviorInsight;

  @override
  Widget build(BuildContext context) {
    return behaviorInsight.when(
      data: (insight) {
        return Card(
          key: ValueKey(insight.suggestion),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Behavior Analytics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                      icon: Icons.checklist_rounded,
                      label:
                          'Completion ${(insight.completionRate * 100).round()}%',
                    ),
                    _MetaChip(
                      icon: Icons.bolt_outlined,
                      label: insight.mostActiveHour == null
                          ? 'Most active time pending'
                          : 'Most active ${_formatHour(insight.mostActiveHour!)}',
                    ),
                    _MetaChip(
                      icon: Icons.tips_and_updates_outlined,
                      label: insight.suggestedSlot == null
                          ? 'Current slots fit well'
                          : 'Suggest ${_slotLabel(insight.suggestedSlot!)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  insight.suggestion,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (insight.overloadWarning != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    insight.overloadWarning!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Analytics unavailable: $error'),
        ),
      ),
    );
  }
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final completed = tasks
        .where((task) => task.status == TaskReminderStatus.completed)
        .length;
    final snoozed = tasks
        .where((task) => task.status == TaskReminderStatus.snoozed)
        .length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Today',
            value: '${tasks.length}',
            detail: 'active tasks',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Done',
            value: '$completed',
            detail: '$snoozed snoozed',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TaskSlotSection extends StatelessWidget {
  const _TaskSlotSection({required this.slot, required this.tasks});

  final TaskSlot slot;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _slotLabel(slot),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 8),
                Text(
                  _slotWindowLabel(slot),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${tasks.length}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No tasks in this slot today.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Column(
                children: [for (final task in tasks) _TaskCard(task: task)],
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
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
                            _MetaChip(
                              icon: Icons.schedule_outlined,
                              label: task.timeLabel,
                            ),
                            _MetaChip(
                              icon: Icons.wb_sunny_outlined,
                              label:
                                  '${_slotLabel(task.slot)} ${_slotWindowLabel(task.slot)}',
                            ),
                            _MetaChip(
                              icon: Icons.repeat_rounded,
                              label: _repeatLabel(task.repeat),
                            ),
                            _MetaChip(
                              icon: Icons.notifications_active_outlined,
                              label: _statusLabel(task.status),
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
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        _showTaskFormSheet(context, ref, existingTask: task),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Next reminder ${_formatReminderTime(task.nextReminderAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await ref
                            .read(tasksControllerProvider.notifier)
                            .markTaskDone(task);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(tasksControllerProvider.notifier)
                            .toggleSnoozeTask(task);
                      },
                      icon: Icon(
                        task.status == TaskReminderStatus.snoozed
                            ? Icons.notifications_active_outlined
                            : Icons.snooze_outlined,
                      ),
                      label: Text(
                        task.status == TaskReminderStatus.snoozed
                            ? 'Unsnooze'
                            : 'Snooze',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTaskFormSheet(
    BuildContext context,
    WidgetRef ref, {
    required Task existingTask,
  }) async {
    final page = TasksPage();
    await page._showTaskFormSheet(context, ref, existingTask: existingTask);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

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

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nothing is scheduled for today yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start with one task in a morning, afternoon, or evening window and Taska will keep the reminder flexible inside that slot.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const _FormInfoBanner(
              icon: Icons.lightbulb_outline,
              message:
                  'Try adding a small recurring routine first, like a morning check-in or evening review, so the reminder engine has behavior to learn from.',
            ),
          ],
        ),
      ),
    );
  }
}

bool _isTodayTask(Task task) {
  final now = DateTime.now();
  final date = task.nextReminderAt;
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

String _slotLabel(TaskSlot slot) {
  switch (slot) {
    case TaskSlot.morning:
      return 'Morning';
    case TaskSlot.afternoon:
      return 'Afternoon';
    case TaskSlot.evening:
      return 'Evening';
  }
}

String _slotWindowLabel(TaskSlot slot) {
  return '(${SlotSchedule.labelForWindow(SlotSchedule.windows[slot]!)})';
}

String _repeatLabel(TaskRepeat repeat) {
  switch (repeat) {
    case TaskRepeat.none:
      return 'No repeat';
    case TaskRepeat.daily:
      return 'Daily';
    case TaskRepeat.weekdays:
      return 'Weekdays';
    case TaskRepeat.weekly:
      return 'Weekly';
  }
}

String _statusLabel(TaskReminderStatus status) {
  switch (status) {
    case TaskReminderStatus.pending:
      return 'Pending';
    case TaskReminderStatus.completed:
      return 'Done';
    case TaskReminderStatus.snoozed:
      return 'Snoozed';
    case TaskReminderStatus.ignored:
      return 'Ignored';
  }
}

String _formatReminderTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.month}/${dateTime.day} $hour:$minute';
}

String _formatHour(int hour) {
  final suffix = hour >= 12 ? 'pm' : 'am';
  final normalized = hour % 12 == 0 ? 12 : hour % 12;
  return '$normalized$suffix';
}

TimeOfDay? _parseTimeLabel(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTimeOfDay(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
