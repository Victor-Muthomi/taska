import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/tasks/presentation/providers/tasks_providers.dart';
import 'behavior_analytics.dart';

final behaviorAnalyticsServiceProvider = Provider<BehaviorAnalytics>((ref) {
  return const BehaviorAnalytics();
});

final behaviorInsightProvider = FutureProvider<BehaviorInsight>((ref) async {
  final tasks = await ref.watch(getTasksUseCaseProvider).call();
  final logs = await ref.watch(getAllTaskLogsUseCaseProvider).call();
  return ref
      .watch(behaviorAnalyticsServiceProvider)
      .analyze(tasks: tasks, logs: logs);
});
