import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taska/core/notifications/notification_providers.dart';
import 'package:taska/core/notifications/notification_service.dart';
import 'package:taska/features/clock/presentation/pages/clock_services_page.dart';

void main() {
  testWidgets('clock screen shows alarm timer and stopwatch tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_clockTestApp());

    expect(find.text('Clock'), findsOneWidget);
    expect(find.text('Alarm'), findsWidgets);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Stopwatch'), findsOneWidget);
    expect(find.text('No alarms set'), findsOneWidget);
  });

  testWidgets('timer duration controls update the countdown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_clockTestApp(initialTabIndex: 1));

    expect(find.text('05:00'), findsOneWidget);

    await tester.ensureVisible(find.text('+5m'));
    await tester.tap(find.text('+5m'), warnIfMissed: false);
    await tester.pump();

    expect(find.text('10:00'), findsOneWidget);

    await tester.ensureVisible(find.text('-1m'));
    await tester.tap(find.text('-1m'), warnIfMissed: false);
    await tester.pump();

    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('stopwatch can start and record a lap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_clockTestApp(initialTabIndex: 2));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Record lap'));
    await tester.pump();

    expect(find.text('Lap 1'), findsOneWidget);
    expect(find.text('No laps yet'), findsNothing);
  });

  testWidgets('timer schedules and cancels os notification hooks', (
    WidgetTester tester,
  ) async {
    final notifications = _FakeClockNotificationService();

    await tester.pumpWidget(
      _clockTestApp(initialTabIndex: 1, notifications: notifications),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    expect(notifications.scheduledTimerCount, 1);
    expect(notifications.lastTimerDuration, const Duration(minutes: 5));

    await tester.tap(find.byTooltip('Reset timer'));
    await tester.pump();

    expect(notifications.canceledTimerCount, 1);
  });
}

Widget _clockTestApp({
  int initialTabIndex = 0,
  _FakeClockNotificationService? notifications,
}) {
  return ProviderScope(
    overrides: [
      if (notifications != null)
        notificationServiceProvider.overrideWithValue(notifications),
    ],
    child: MaterialApp(
      home: Scaffold(body: ClockServicesPage(initialTabIndex: initialTabIndex)),
    ),
  );
}

class _FakeClockNotificationService extends NotificationService {
  int scheduledTimerCount = 0;
  int canceledTimerCount = 0;
  Duration? lastTimerDuration;

  @override
  Future<void> scheduleClockTimer({
    required DateTime scheduledAt,
    required Duration duration,
  }) async {
    scheduledTimerCount += 1;
    lastTimerDuration = duration;
  }

  @override
  Future<void> cancelClockTimer() async {
    canceledTimerCount += 1;
  }
}
