import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shopping/data/datasources/shopping_local_data_source.dart';
import '../../features/shopping/data/repositories/shopping_repository_impl.dart';
import '../../features/shopping/domain/repositories/shopping_repository.dart';
import '../../features/tasks/domain/repositories/tasks_repository.dart';
import '../../features/tasks/presentation/providers/tasks_providers.dart';
import '../database/app_database.dart';
import '../reminders/reminder_engine_providers.dart';
import 'shopping_event_logger.dart';
import 'shopping_service.dart';

final shoppingLocalDataSourceProvider = Provider<ShoppingLocalDataSource>((ref) {
  return ShoppingLocalDataSource(databaseHelper: ref.watch(appDatabaseProvider));
});

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepositoryImpl(
    localDataSource: ref.watch(shoppingLocalDataSourceProvider),
  );
});

final shoppingEventLoggerProvider = Provider<ShoppingEventLogger>((ref) {
  return ShoppingEventLoggerImpl(database: ref.watch(appDatabaseProvider));
});

final shoppingServiceProvider = Provider<ShoppingService>((ref) {
  return ShoppingService(
    shoppingRepository: ref.watch(shoppingRepositoryProvider),
    tasksRepository: ref.watch(tasksRepositoryProvider),
    eventLogger: ref.watch(shoppingEventLoggerProvider),
    reminderEngine: ref.watch(reminderEngineProvider),
  );
});