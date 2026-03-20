import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings_providers.dart';
import 'reminder_engine.dart';

final reminderEngineProvider = Provider<ReminderEngine>((ref) {
  return ReminderEngine(settings: ref.watch(appSettingsProvider));
});
