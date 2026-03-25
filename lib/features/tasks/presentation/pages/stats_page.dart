import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/behavior_analytics.dart';
import '../../../../core/analytics/behavior_analytics_providers.dart';
import '../../../../core/rewards/models/achievement.dart';
import '../../../../core/rewards/models/user_stats.dart';
import '../../../../core/rewards/reward_state_providers.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_providers.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksControllerProvider);
    final insightState = ref.watch(behaviorInsightProvider);
    final rewardStatsState = ref.watch(rewardUserStatsProvider);
    final achievementsState = ref.watch(rewardAchievementsProvider);

    final body = tasksState.when(
      data: (tasks) => insightState.when(
        data: (insight) => rewardStatsState.when(
          data: (stats) => achievementsState.when(
            data: (achievements) => _StatsBody(
              tasks: tasks,
              insight: insight,
              stats: stats,
              achievements: achievements,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Achievements unavailable: $error'),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Streaks unavailable: $error'),
          ),
        ),
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
  const _StatsBody({
    required this.tasks,
    required this.insight,
    required this.stats,
    required this.achievements,
  });

  final List<Task> tasks;
  final BehaviorInsight insight;
  final UserStats stats;
  final List<Achievement> achievements;

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
        const SizedBox(height: 16),
        _BehaviorInsights(behaviorInsight: AsyncValue.data(insight)),
        const SizedBox(height: 20),
        Text('Reward Progress', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatsCard(
                label: 'Current Streak',
                value: '${stats.currentStreak}',
                helper: stats.lastCompletedDate == null
                    ? 'No completed day yet'
                    : 'Last completed ${_formatDate(stats.lastCompletedDate!)}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatsCard(
                label: 'Longest Streak',
                value: '${stats.longestStreak}',
                helper: stats.longestStreak == 0
                    ? 'Build your first streak'
                    : 'Best run so far',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Achievements',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (achievements.isEmpty)
                  Text(
                    'No achievements unlocked yet. Keep completing tasks to earn the first one.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final achievement in achievements)
                        _AchievementChip(achievement: achievement),
                    ],
                  ),
              ],
            ),
          ),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: achievement.description,
      child: Chip(
        avatar: const Icon(Icons.emoji_events_outlined, size: 18),
        label: Text(achievement.title),
      ),
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
    case TaskSlot.night:
      return 'Night';
  }
}

String _formatHour(int hour) {
  final suffix = hour >= 12 ? 'pm' : 'am';
  final normalized = hour % 12 == 0 ? 12 : hour % 12;
  return '$normalized$suffix';
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
