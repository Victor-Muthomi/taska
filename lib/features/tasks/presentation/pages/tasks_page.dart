import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_providers.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(sampleTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            AppStrings.appTagline,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Foundation ready for clean architecture, local storage, and adaptive reminders.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          for (final task in tasks) _TaskPreviewCard(task: task),
        ],
      ),
    );
  }
}

class _TaskPreviewCard extends StatelessWidget {
  const _TaskPreviewCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(task.title),
        subtitle: Text(_slotLabel(task.slot)),
        trailing: Chip(label: Text(_statusLabel(task.status))),
      ),
    );
  }

  String _slotLabel(TaskSlot slot) {
    switch (slot) {
      case TaskSlot.morning:
        return 'Morning slot';
      case TaskSlot.afternoon:
        return 'Afternoon slot';
      case TaskSlot.evening:
        return 'Evening slot';
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
}
