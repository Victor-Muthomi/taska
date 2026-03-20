import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/behavior_analytics.dart';
import '../../../../core/analytics/behavior_analytics_providers.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_providers.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksControllerProvider);
    final insightState = ref.watch(behaviorInsightProvider);

    final body = tasksState.when(
      data: (tasks) => insightState.when(
        data: (insight) => _StatsBody(tasks: tasks, insight: insight),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Stats unavailable: $error')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Tasks unavailable: $error')),
    );

    if (embedded) {
      return SafeArea(child: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: body,
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.tasks, required this.insight});

  final List<Task> tasks;
  final BehaviorInsight insight;

  @override
  Widget build(BuildContext context) {
    final completed = tasks
        .where((task) => task.status == TaskReminderStatus.completed)
        .length;
    final pending = tasks
        .where((task) => task.status == TaskReminderStatus.pending)
        .length;
    final snoozed = tasks
        .where((task) => task.status == TaskReminderStatus.snoozed)
        .length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Stats', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'A quick read on how your schedule is actually behaving.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text('Overview', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatsCard(
                label: 'Completion',
                value: '${(insight.completionRate * 100).round()}%',
                helper: 'completion rate',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatsCard(
                label: 'Most Active',
                value: insight.mostActiveHour == null
                    ? '--'
                    : _formatHour(insight.mostActiveHour!),
                helper: insight.mostActiveSlot == null
                    ? 'not enough data'
                    : '${_slotLabel(insight.mostActiveSlot!)} slot',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatsCard(
                label: 'Completed',
                value: '$completed',
                helper: '$pending pending',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatsCard(
                label: 'Snoozed',
                value: '$snoozed',
                helper: insight.suggestedSlot == null
                    ? 'slots balanced'
                    : 'try ${_slotLabel(insight.suggestedSlot!)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggestion',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text(insight.suggestion),
                if (insight.overloadWarning != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    insight.overloadWarning!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

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
            Text(helper, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
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

String _formatHour(int hour) {
  final suffix = hour >= 12 ? 'pm' : 'am';
  final normalized = hour % 12 == 0 ? 12 : hour % 12;
  return '$normalized$suffix';
}
