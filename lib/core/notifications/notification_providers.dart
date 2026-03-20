import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationEventsProvider = StreamProvider<NotificationEvent>((ref) {
  return ref.watch(notificationServiceProvider).events;
});
