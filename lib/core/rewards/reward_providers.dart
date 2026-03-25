import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../notifications/notification_providers.dart';
import 'repository/reward_repository.dart';
import 'repository/reward_repository_impl.dart';
import 'services/reward_engine.dart';

final rewardRepositoryProvider = Provider<RewardRepository>((ref) {
  return RewardRepositoryImpl(databaseGetter: () => AppDatabase.instance.database);
});

final rewardEngineProvider = Provider<RewardEngine>((ref) {
  return RewardEngine(
    repository: ref.watch(rewardRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});