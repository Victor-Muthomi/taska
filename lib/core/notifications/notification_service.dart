import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/tasks/domain/entities/task.dart';
import '../settings/app_settings.dart';
import 'notification_channels.dart';
import 'notification_logic.dart';
import 'notification_payload.dart';

final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

const int _comebackReminderNotificationId = 9000001;
const int _clockTimerNotificationId = 9100001;
const int _clockAlarmNotificationIdBase = 9200000;

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  await _handleNotificationResponse(response);
}

Future<void> _handleNotificationResponse(NotificationResponse response) async {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) {
    return;
  }

  final notificationPayload = NotificationPayload.fromJson(payload);
  if (response.actionId == snoozeNotificationActionId) {
    await _scheduleSnoozedNotification(
      payload: notificationPayload,
      priority: notificationPayload.priority,
    );
  }
}

Future<void> _scheduleSnoozedNotification({
  required NotificationPayload payload,
  required ReminderPriority priority,
}) async {
  tz.initializeTimeZones();
  final scheduledTime = tz.TZDateTime.now(
    tz.local,
  ).add(Duration(minutes: payload.snoozeMinutes));

  await _notificationsPlugin.zonedSchedule(
    payload.taskId,
    payload.title,
    payload.notes ?? 'Snoozed reminder',
    scheduledTime,
    _buildNotificationDetails(priority, snoozeMinutes: payload.snoozeMinutes),
    payload: payload.toJson(),
    androidScheduleMode: await _resolveScheduleModeFromPlugin(),
  );
}

Future<AndroidScheduleMode> _resolveScheduleModeFromPlugin() async {
  final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin
  >();
  if (androidPlugin == null) {
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  final canScheduleExact = await androidPlugin.canScheduleExactNotifications();
  if (canScheduleExact) {
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  final requested = await androidPlugin.requestExactAlarmsPermission();
  if (requested == true) {
    return AndroidScheduleMode.exactAllowWhileIdle;
  }
  final canScheduleAfterPrompt =
      await androidPlugin.canScheduleExactNotifications();
  if (canScheduleAfterPrompt) {
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  return AndroidScheduleMode.inexactAllowWhileIdle;
}

class NotificationEvent {
  const NotificationEvent({required this.taskId, required this.type});

  final int taskId;
  final NotificationEventType type;
}

class NotificationService {
  NotificationService();

  final StreamController<NotificationEvent> _eventsController =
      StreamController<NotificationEvent>.broadcast();

  Stream<NotificationEvent> get events => _eventsController.stream;

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createChannels();
    await _requestPermissions();

    final launchDetails = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (response?.payload != null && response?.payload?.isNotEmpty == true) {
      final payload = NotificationPayload.fromJson(response!.payload!);
      _eventsController.add(
        NotificationEvent(
          taskId: payload.taskId,
          type: NotificationEventType.opened,
        ),
      );
    }
  }

  Future<void> scheduleTaskNotification({
    required Task task,
    required AppSettings settings,
    ReminderPriority? priority,
  }) async {
    final taskId = task.id;
    if (taskId == null) {
      return;
    }

    final scheduledAt = task.nextReminderAt;
    final resolvedPriority =
        priority ??
        NotificationLogic.resolvePriority(
          intensity: task.reminderIntensity,
          preferredPriority: settings.preferredNotificationPriority,
          allowPriorityEscalation: settings.allowPriorityEscalation,
        );
    final payload = NotificationPayload.fromTask(
      task,
      snoozeMinutes: settings.defaultSnoozeMinutes,
      priority: resolvedPriority,
    );

    await _notificationsPlugin.zonedSchedule(
      taskId,
      task.title,
      task.notes ?? 'It is time for your ${task.slot.name} task.',
      tz.TZDateTime.from(scheduledAt, tz.local),
      _buildNotificationDetails(
        resolvedPriority,
        snoozeMinutes: settings.defaultSnoozeMinutes,
      ),
      payload: payload.toJson(),
      androidScheduleMode: await _resolveScheduleModeFromPlugin(),
    );
  }

  Future<void> cancelTaskNotification(int taskId) {
    return _notificationsPlugin.cancel(taskId);
  }

  Future<void> scheduleClockAlarm({
    required int alarmId,
    required DateTime scheduledAt,
    required String timeLabel,
  }) async {
    await _scheduleClockNotification(
      id: _clockAlarmNotificationIdBase + alarmId,
      title: 'Taska alarm',
      body: 'It is $timeLabel.',
      scheduledAt: scheduledAt,
      payload: '{"type":"clock_alarm","alarmId":$alarmId}',
    );
  }

  Future<void> cancelClockAlarm(int alarmId) {
    return _notificationsPlugin.cancel(_clockAlarmNotificationIdBase + alarmId);
  }

  Future<void> scheduleClockTimer({
    required DateTime scheduledAt,
    required Duration duration,
  }) async {
    await _scheduleClockNotification(
      id: _clockTimerNotificationId,
      title: 'Taska timer finished',
      body: 'Your ${_formatClockDuration(duration)} countdown is complete.',
      scheduledAt: scheduledAt,
      payload: '{"type":"clock_timer"}',
    );
  }

  Future<void> cancelClockTimer() {
    return _notificationsPlugin.cancel(_clockTimerNotificationId);
  }

  Future<void> scheduleComebackReminder({required DateTime scheduledAt}) async {
    await cancelComebackReminder();

    final scheduledTime = tz.TZDateTime.from(scheduledAt, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      await _notificationsPlugin.show(
        _comebackReminderNotificationId,
        'Come back to Taska',
        'You have not logged any task activity for 2 days. Pick up where you left off.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'taska_normal_priority',
            'Smart Reminders',
            channelDescription: 'Default reminders for scheduled tasks.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      _comebackReminderNotificationId,
      'Come back to Taska',
      'You have not logged any task activity for 2 days. Pick up where you left off.',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'taska_normal_priority',
          'Smart Reminders',
          channelDescription: 'Default reminders for scheduled tasks.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: '{"type":"comeback_reminder"}',
      androidScheduleMode: await _resolveScheduleModeFromPlugin(),
    );
  }

  Future<void> cancelComebackReminder() {
    return _notificationsPlugin.cancel(_comebackReminderNotificationId);
  }

  Future<void> _scheduleClockNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  }) async {
    final scheduledTime = tz.TZDateTime.from(scheduledAt, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        _buildClockNotificationDetails(),
        payload: payload,
      );
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      _buildClockNotificationDetails(),
      payload: payload,
      androidScheduleMode: await _resolveScheduleModeFromPlugin(),
    );
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    final notificationPayload = NotificationPayload.fromJson(payload);
    final eventType = NotificationLogic.eventTypeForActionId(response.actionId);

    _eventsController.add(
      NotificationEvent(taskId: notificationPayload.taskId, type: eventType),
    );
  }

  Future<void> _createChannels() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) {
      return;
    }

    for (final priority in ReminderPriority.values) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          priority.channelId,
          priority.channelName,
          description: priority.channelDescription,
          importance: priority.importance,
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }
}

NotificationDetails _buildClockNotificationDetails() {
  return const NotificationDetails(
    android: AndroidNotificationDetails(
      'taska_high_priority',
      'Urgent Reminders',
      channelDescription:
          'High priority reminders for tasks that need attention.',
      importance: Importance.max,
      priority: Priority.max,
    ),
    iOS: DarwinNotificationDetails(),
  );
}

NotificationDetails _buildNotificationDetails(
  ReminderPriority priority, {
  required int snoozeMinutes,
}) {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      priority.channelId,
      priority.channelName,
      channelDescription: priority.channelDescription,
      importance: priority.importance,
      priority: priority.priority,
      actions: [
        AndroidNotificationAction(
          snoozeNotificationActionId,
          'Snooze $snoozeMinutes min',
          cancelNotification: true,
        ),
      ],
    ),
    iOS: const DarwinNotificationDetails(),
  );
}

String _formatClockDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m';
  }
  return '${seconds}s';
}
