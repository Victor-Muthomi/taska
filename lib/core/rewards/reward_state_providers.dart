import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rewards/models/achievement.dart';
import '../rewards/models/user_stats.dart';
import 'reward_providers.dart';

final rewardUserStatsProvider = FutureProvider<UserStats>((ref) async {
  return ref.watch(rewardEngineProvider).getUserStats();
});

final rewardAchievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  return ref.watch(rewardEngineProvider).getUnlockedAchievements();
});