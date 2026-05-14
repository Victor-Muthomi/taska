import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_providers.dart';
import '../../data/clock_runtime_storage.dart';
import '../../services/clock_runtime_service.dart';

class ClockServicesPage extends ConsumerStatefulWidget {
  const ClockServicesPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<ClockServicesPage> createState() => _ClockServicesPageState();
}

class _ClockServicesPageState extends ConsumerState<ClockServicesPage>
    with SingleTickerProviderStateMixin {
  static const _maxTimerDurationSeconds = 359940; // 99:59:00
  static const _clockRuntimeStorage = ClockRuntimeStorage();
  static const _clockRuntimeService = ClockRuntimeService();

  late final TabController _tabController;
  Timer? _ticker;

  final List<_AlarmEntry> _alarms = [];
  int _nextAlarmId = 1;

  Duration _timerDuration = const Duration(minutes: 5);
  Duration _timerRemaining = const Duration(minutes: 5);
  DateTime? _timerEndsAt;
  bool _timerRunning = false;

  DateTime? _stopwatchStartedAt;
  Duration _stopwatchElapsedBeforeStart = Duration.zero;
  Duration _stopwatchElapsed = Duration.zero;
  bool _stopwatchRunning = false;
  final List<Duration> _laps = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) {
        return;
      }
      _syncClockState();
    });
    unawaited(_restoreClockRuntimeState());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clock', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Alarm, timer, and stopwatch tools for the work sitting next to your tasks.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.alarm_outlined), text: 'Alarm'),
                    Tab(icon: Icon(Icons.timer_outlined), text: 'Timer'),
                    Tab(icon: Icon(Icons.av_timer_outlined), text: 'Stopwatch'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AlarmPanel(
                  alarms: _alarms,
                  onAddAlarm: _addAlarm,
                  onToggleAlarm: _toggleAlarm,
                  onDeleteAlarm: _deleteAlarm,
                ),
                _TimerPanel(
                  duration: _timerDuration,
                  remaining: _timerRemaining,
                  running: _timerRunning,
                  onAdjustDuration: _adjustTimerDuration,
                  onStartPause: _toggleTimer,
                  onReset: _resetTimer,
                ),
                _StopwatchPanel(
                  elapsed: _stopwatchElapsed,
                  running: _stopwatchRunning,
                  laps: _laps,
                  onStartPause: _toggleStopwatch,
                  onLap: _recordLap,
                  onReset: _resetStopwatch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addAlarm() async {
    final now = TimeOfDay.now();
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
    );
    if (selected == null) {
      return;
    }

    final alarm = _AlarmEntry(
      id: _nextAlarmId++,
      time: selected,
      nextRingAt: _nextAlarmDateTime(selected),
    );

    setState(() {
      _alarms.add(alarm);
      _alarms.sort((a, b) => a.nextRingAt.compareTo(b.nextRingAt));
    });
    _scheduleAlarmNotification(alarm);
    _persistClockRuntimeState();
  }

  void _toggleAlarm(_AlarmEntry alarm, bool enabled) {
    setState(() {
      final index = _alarms.indexWhere((entry) => entry.id == alarm.id);
      if (index == -1) {
        return;
      }
      final updatedAlarm = alarm.copyWith(
        enabled: enabled,
        nextRingAt: enabled ? _nextAlarmDateTime(alarm.time) : alarm.nextRingAt,
      );
      _alarms[index] = updatedAlarm;
      if (enabled) {
        _scheduleAlarmNotification(updatedAlarm);
      } else {
        _cancelAlarmNotification(updatedAlarm);
      }
    });
    _persistClockRuntimeState();
  }

  void _deleteAlarm(_AlarmEntry alarm) {
    setState(() {
      _alarms.removeWhere((entry) => entry.id == alarm.id);
    });
    _cancelAlarmNotification(alarm);
    _persistClockRuntimeState();
  }

  void _adjustTimerDuration(Duration delta) {
    if (_timerRunning) {
      return;
    }
    final nextSeconds = (_timerDuration + delta).inSeconds.clamp(
      0,
      _maxTimerDurationSeconds,
    );
    final next = Duration(seconds: nextSeconds);
    setState(() {
      _timerDuration = next;
      _timerRemaining = next;
    });
    _persistClockRuntimeState();
  }

  void _toggleTimer() {
    if (_timerRemaining == Duration.zero && !_timerRunning) {
      setState(() {
        _timerRemaining = _timerDuration;
      });
    }
    if (_timerRemaining == Duration.zero) {
      return;
    }

    setState(() {
      if (_timerRunning) {
        _timerRunning = false;
        _timerEndsAt = null;
        _cancelTimerNotification();
      } else {
        _timerRunning = true;
        _timerEndsAt = DateTime.now().add(_timerRemaining);
        _scheduleTimerNotification();
      }
    });
    _persistClockRuntimeState();
  }

  void _resetTimer() {
    setState(() {
      _timerRunning = false;
      _timerEndsAt = null;
      _timerRemaining = _timerDuration;
    });
    _cancelTimerNotification();
    _persistClockRuntimeState();
  }

  void _toggleStopwatch() {
    setState(() {
      if (_stopwatchRunning) {
        _stopwatchElapsedBeforeStart = _stopwatchElapsed;
        _stopwatchStartedAt = null;
        _stopwatchRunning = false;
      } else {
        _stopwatchStartedAt = DateTime.now();
        _stopwatchRunning = true;
      }
    });
  }

  void _recordLap() {
    if (!_stopwatchRunning) {
      return;
    }
    setState(() {
      _laps.insert(0, _stopwatchElapsed);
    });
  }

  void _resetStopwatch() {
    setState(() {
      _stopwatchRunning = false;
      _stopwatchStartedAt = null;
      _stopwatchElapsedBeforeStart = Duration.zero;
      _stopwatchElapsed = Duration.zero;
      _laps.clear();
    });
  }

  void _syncClockState() {
    final now = DateTime.now();
    var shouldSetState = false;
    final triggeredAlarms = <_AlarmEntry>[];

    for (var i = 0; i < _alarms.length; i++) {
      final alarm = _alarms[i];
      if (alarm.enabled && !now.isBefore(alarm.nextRingAt)) {
        triggeredAlarms.add(alarm);
        _alarms[i] = alarm.copyWith(enabled: false);
        _cancelAlarmNotification(alarm);
        shouldSetState = true;
      }
    }

    if (_timerRunning && _timerEndsAt != null) {
      final remaining = _timerEndsAt!.difference(now);
      final nextRemaining = remaining.isNegative ? Duration.zero : remaining;
      if (nextRemaining != _timerRemaining) {
        _timerRemaining = nextRemaining;
        shouldSetState = true;
      }
      if (nextRemaining == Duration.zero) {
        _timerRunning = false;
        _timerEndsAt = null;
        shouldSetState = true;
        _cancelTimerNotification();
        _showClockAlert('Timer finished', 'Your countdown is complete.');
      }
    }

    if (_stopwatchRunning && _stopwatchStartedAt != null) {
      _stopwatchElapsed =
          _stopwatchElapsedBeforeStart + now.difference(_stopwatchStartedAt!);
      shouldSetState = true;
    }

    if (shouldSetState) {
      setState(() {});
      _persistClockRuntimeState();
    }

    for (final alarm in triggeredAlarms) {
      _showClockAlert('Alarm', 'It is ${_formatTimeOfDay(alarm.time)}.');
    }
  }

  DateTime _nextAlarmDateTime(TimeOfDay time) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  void _showClockAlert(String title, String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scheduleAlarmNotification(_AlarmEntry alarm) {
    unawaited(
      ref
          .read(notificationServiceProvider)
          .scheduleClockAlarm(
            alarmId: alarm.id,
            scheduledAt: alarm.nextRingAt,
            timeLabel: _formatTimeOfDay(alarm.time),
          ),
    );
  }

  void _cancelAlarmNotification(_AlarmEntry alarm) {
    unawaited(ref.read(notificationServiceProvider).cancelClockAlarm(alarm.id));
  }

  void _scheduleTimerNotification() {
    final timerEndsAt = _timerEndsAt;
    if (timerEndsAt == null) {
      return;
    }

    unawaited(
      ref
          .read(notificationServiceProvider)
          .scheduleClockTimer(
            scheduledAt: timerEndsAt,
            duration: _timerRemaining,
          ),
    );
  }

  void _cancelTimerNotification() {
    unawaited(ref.read(notificationServiceProvider).cancelClockTimer());
  }

  Future<void> _restoreClockRuntimeState() async {
    final state = await _clockRuntimeStorage.load();
    if (!mounted) {
      return;
    }

    final now = DateTime.now();
    final restoredAlarms = <_AlarmEntry>[];
    for (final alarm in state.alarms) {
      if (alarm.id <= 0) {
        continue;
      }
      final time = TimeOfDay(hour: alarm.hour, minute: alarm.minute);
      var nextRingAt = DateTime.tryParse(alarm.nextRingAtUtcIso)?.toLocal();
      nextRingAt ??= _nextAlarmDateTime(time);
      if (alarm.enabled && !nextRingAt.isAfter(now)) {
        nextRingAt = _nextAlarmDateTime(time);
      }
      restoredAlarms.add(
        _AlarmEntry(
          id: alarm.id,
          time: time,
          nextRingAt: nextRingAt,
          enabled: alarm.enabled,
        ),
      );
    }
    restoredAlarms.sort((a, b) => a.nextRingAt.compareTo(b.nextRingAt));

    final restoredTimerDuration = Duration(
      seconds: state.timerDurationSeconds.clamp(0, _maxTimerDurationSeconds)
          .toInt(),
    );
    final restoredEndsAtUtc = state.timerEndsAtUtcIso == null
        ? null
        : DateTime.tryParse(state.timerEndsAtUtcIso!);
    final restoredEndsAt = restoredEndsAtUtc?.toLocal();
    final restoredTimerRemaining = restoredEndsAt == null
        ? restoredTimerDuration
        : restoredEndsAt.difference(now);
    final timerRunning = restoredTimerRemaining > Duration.zero;

    setState(() {
      _alarms
        ..clear()
        ..addAll(restoredAlarms);
      _nextAlarmId = math.max(
        state.nextAlarmId,
        _maxAlarmId(_alarms) + 1,
      );
      _timerDuration = restoredTimerDuration;
      _timerRemaining = timerRunning ? restoredTimerRemaining : _timerDuration;
      _timerEndsAt = timerRunning ? restoredEndsAt : null;
      _timerRunning = timerRunning;
    });

    for (final alarm in restoredAlarms.where((alarm) => alarm.enabled)) {
      _scheduleAlarmNotification(alarm);
    }
    if (timerRunning && restoredEndsAt != null) {
      unawaited(
        ref
            .read(notificationServiceProvider)
            .scheduleClockTimer(
              scheduledAt: restoredEndsAt,
              duration: restoredTimerRemaining,
            ),
      );
    }

    _syncRuntimeServiceState();
  }

  void _persistClockRuntimeState() {
    final state = ClockRuntimeState(
      nextAlarmId: _nextAlarmId,
      alarms: _alarms
          .map(
            (alarm) => StoredClockAlarm(
              id: alarm.id,
              hour: alarm.time.hour,
              minute: alarm.time.minute,
              nextRingAtUtcIso: alarm.nextRingAt.toUtc().toIso8601String(),
              enabled: alarm.enabled,
            ),
          )
          .toList(growable: false),
      timerDurationSeconds: _timerDuration.inSeconds,
      timerEndsAtUtcIso: _timerRunning
          ? _timerEndsAt?.toUtc().toIso8601String()
          : null,
    );
    unawaited(_clockRuntimeStorage.save(state));
    _syncRuntimeServiceState();
  }

  void _syncRuntimeServiceState() {
    unawaited(
      (_timerRunning || _alarms.any((alarm) => alarm.enabled))
          ? _clockRuntimeService.start()
          : _clockRuntimeService.stop(),
    );
  }

  int _maxAlarmId(List<_AlarmEntry> alarms) {
    if (alarms.isEmpty) {
      return 0;
    }
    return alarms.map((alarm) => alarm.id).reduce(math.max);
  }
}

class _AlarmPanel extends StatelessWidget {
  const _AlarmPanel({
    required this.alarms,
    required this.onAddAlarm,
    required this.onToggleAlarm,
    required this.onDeleteAlarm,
  });

  final List<_AlarmEntry> alarms;
  final VoidCallback onAddAlarm;
  final void Function(_AlarmEntry alarm, bool enabled) onToggleAlarm;
  final ValueChanged<_AlarmEntry> onDeleteAlarm;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        _PanelHeader(
          title: 'Alarms',
          subtitle: 'Set one-time alarms for today or tomorrow.',
          action: FilledButton.icon(
            onPressed: onAddAlarm,
            icon: const Icon(Icons.add_alarm_rounded),
            label: const Text('Add'),
          ),
        ),
        const SizedBox(height: 12),
        if (alarms.isEmpty)
          const _EmptyClockCard(
            icon: Icons.alarm_off_outlined,
            title: 'No alarms set',
            subtitle: 'Add an alarm when a task needs a hard stop.',
          )
        else
          for (final alarm in alarms) ...[
            Card(
              child: ListTile(
                leading: Icon(
                  alarm.enabled
                      ? Icons.alarm_on_outlined
                      : Icons.alarm_off_outlined,
                ),
                title: Text(
                  _formatTimeOfDay(alarm.time),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                subtitle: Text(
                  alarm.enabled
                      ? 'Rings ${_relativeDayLabel(alarm.nextRingAt)}'
                      : 'Off',
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Switch(
                      value: alarm.enabled,
                      onChanged: (value) => onToggleAlarm(alarm, value),
                    ),
                    IconButton(
                      onPressed: () => onDeleteAlarm(alarm),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Delete alarm',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({
    required this.duration,
    required this.remaining,
    required this.running,
    required this.onAdjustDuration,
    required this.onStartPause,
    required this.onReset,
  });

  final Duration duration;
  final Duration remaining;
  final bool running;
  final ValueChanged<Duration> onAdjustDuration;
  final VoidCallback onStartPause;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : remaining.inMilliseconds / duration.inMilliseconds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        const _PanelHeader(
          title: 'Timer',
          subtitle: 'Run a focused countdown without leaving Taska.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  height: 164,
                  width: 164,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 10,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Text(
                        _formatDuration(remaining),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DurationButton(
                      label: '-1m',
                      onPressed: running
                          ? null
                          : () => onAdjustDuration(const Duration(minutes: -1)),
                    ),
                    _DurationButton(
                      label: '+1m',
                      onPressed: running
                          ? null
                          : () => onAdjustDuration(const Duration(minutes: 1)),
                    ),
                    _DurationButton(
                      label: '+5m',
                      onPressed: running
                          ? null
                          : () => onAdjustDuration(const Duration(minutes: 5)),
                    ),
                    _DurationButton(
                      label: '+15m',
                      onPressed: running
                          ? null
                          : () => onAdjustDuration(const Duration(minutes: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: duration == Duration.zero
                            ? null
                            : onStartPause,
                        icon: Icon(
                          running
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(running ? 'Pause' : 'Start'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt_rounded),
                      tooltip: 'Reset timer',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StopwatchPanel extends StatelessWidget {
  const _StopwatchPanel({
    required this.elapsed,
    required this.running,
    required this.laps,
    required this.onStartPause,
    required this.onLap,
    required this.onReset,
  });

  final Duration elapsed;
  final bool running;
  final List<Duration> laps;
  final VoidCallback onStartPause;
  final VoidCallback onLap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        const _PanelHeader(
          title: 'Stopwatch',
          subtitle: 'Track elapsed time and capture laps.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  _formatStopwatch(elapsed),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onStartPause,
                        icon: Icon(
                          running
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(running ? 'Pause' : 'Start'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: running ? onLap : null,
                      icon: const Icon(Icons.flag_outlined),
                      tooltip: 'Record lap',
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt_rounded),
                      tooltip: 'Reset stopwatch',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (laps.isEmpty)
          const _EmptyClockCard(
            icon: Icons.flag_outlined,
            title: 'No laps yet',
            subtitle: 'Start the stopwatch and tap the flag to save a split.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < laps.length; i++)
                  ListTile(
                    leading: CircleAvatar(child: Text('${laps.length - i}')),
                    title: Text(_formatStopwatch(laps[i])),
                    subtitle: Text('Lap ${laps.length - i}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class _DurationButton extends StatelessWidget {
  const _DurationButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class _EmptyClockCard extends StatelessWidget {
  const _EmptyClockCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmEntry {
  const _AlarmEntry({
    required this.id,
    required this.time,
    required this.nextRingAt,
    this.enabled = true,
  });

  final int id;
  final TimeOfDay time;
  final DateTime nextRingAt;
  final bool enabled;

  _AlarmEntry copyWith({TimeOfDay? time, DateTime? nextRingAt, bool? enabled}) {
    return _AlarmEntry(
      id: id,
      time: time ?? this.time,
      nextRingAt: nextRingAt ?? this.nextRingAt,
      enabled: enabled ?? this.enabled,
    );
  }
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _relativeDayLabel(DateTime dateTime) {
  final today = DateUtils.dateOnly(DateTime.now());
  final alarmDay = DateUtils.dateOnly(dateTime);
  final formattedTime = _formatTimeOfDay(
    TimeOfDay(hour: dateTime.hour, minute: dateTime.minute),
  );
  if (DateUtils.isSameDay(today, alarmDay)) {
    return 'today at $formattedTime';
  }
  if (DateUtils.isSameDay(today.add(const Duration(days: 1)), alarmDay)) {
    return 'tomorrow at $formattedTime';
  }
  return formattedTime;
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String _formatStopwatch(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hundredths = (duration.inMilliseconds.remainder(1000) ~/ 10)
      .toString()
      .padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds.$hundredths';
  }
  return '$minutes:$seconds.$hundredths';
}
