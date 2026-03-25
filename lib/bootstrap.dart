import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/notifications/notification_providers.dart';
import 'core/rewards/reward_providers.dart';
import 'core/scheduling/slot_schedule.dart';
import 'core/settings/app_settings_providers.dart';
import 'core/settings/app_settings_storage.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  const settingsStorage = AppSettingsStorage();
  final initialSettings = await settingsStorage.load();
  SlotSchedule.configure(initialSettings.slotWindows);
  final container = ProviderContainer(
    overrides: [
      appSettingsStorageProvider.overrideWithValue(settingsStorage),
      initialAppSettingsProvider.overrideWithValue(initialSettings),
    ],
  );
  await container.read(notificationServiceProvider).initialize();
  await container.read(rewardEngineProvider).refreshFromLogs();
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
