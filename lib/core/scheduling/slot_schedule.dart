import '../../features/tasks/domain/entities/task.dart';

class SlotWindow {
  const SlotWindow({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.label,
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String? label;

  SlotWindow copyWith({
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    String? label,
  }) {
    return SlotWindow(
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      label: label ?? this.label,
    );
  }
}

class SlotSchedule {
  const SlotSchedule._();

  static const defaultWindows = <TaskSlot, SlotWindow>{
    TaskSlot.morning: SlotWindow(
      startHour: 6,
      startMinute: 0,
      endHour: 12,
      endMinute: 0,
    ),
    TaskSlot.afternoon: SlotWindow(
      startHour: 12,
      startMinute: 0,
      endHour: 17,
      endMinute: 0,
    ),
    TaskSlot.evening: SlotWindow(
      startHour: 17,
      startMinute: 0,
      endHour: 22,
      endMinute: 0,
    ),
  };

  static Map<TaskSlot, SlotWindow> _windows = {
    for (final entry in defaultWindows.entries) entry.key: entry.value,
  };

  static Map<TaskSlot, SlotWindow> get windows => _windows;

  static void configure(Map<TaskSlot, SlotWindow> windows) {
    _windows = {
      for (final slot in TaskSlot.values)
        slot: windows[slot] ?? defaultWindows[slot]!,
    };
  }

  static String normalizeTimeForSlot(String timeLabel, TaskSlot slot) {
    final time = parseTimeLabel(timeLabel);
    final minutes = time.hour * 60 + time.minute;
    final window = windows[slot]!;
    final start = window.startHour * 60 + window.startMinute;
    final endExclusive = window.endHour * 60 + window.endMinute;
    final clamped = minutes < start
        ? start
        : (minutes >= endExclusive ? endExclusive - 1 : minutes);

    return formatHourMinute(hour: clamped ~/ 60, minute: clamped % 60);
  }

  static DateTime nextDateTimeForTask({
    required String timeLabel,
    required TaskSlot slot,
    TaskRepeat repeat = TaskRepeat.none,
    DateTime? from,
  }) {
    final now = from ?? DateTime.now();
    final normalized = normalizeTimeForSlot(timeLabel, slot);
    final time = parseTimeLabel(normalized);

    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    candidate = _advanceToValidOccurrence(candidate, repeat: repeat, now: now);

    return candidate;
  }

  static DateTime nextOccurrenceFromCompletion({
    required DateTime completedAt,
    required String timeLabel,
    required TaskSlot slot,
    required TaskRepeat repeat,
  }) {
    final normalized = normalizeTimeForSlot(timeLabel, slot);
    final time = parseTimeLabel(normalized);
    final base = DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day,
      time.hour,
      time.minute,
    );

    return _advanceToValidOccurrence(
      base,
      repeat: repeat,
      now: completedAt,
      forceFuture: true,
    );
  }

  static ParsedTime parseTimeLabel(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return const ParsedTime(hour: 8, minute: 0);
    }

    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    return ParsedTime(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  static String formatHourMinute({required int hour, required int minute}) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String labelForWindow(SlotWindow window) {
    if (window.label != null && window.label!.isNotEmpty) {
      return window.label!;
    }

    return '${formatHourMinute(hour: window.startHour, minute: window.startMinute)}-${formatHourMinute(hour: window.endHour, minute: window.endMinute)}';
  }

  static DateTime _advanceToValidOccurrence(
    DateTime candidate, {
    required TaskRepeat repeat,
    required DateTime now,
    bool forceFuture = false,
  }) {
    if (repeat == TaskRepeat.none) {
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    while (!candidate.isAfter(now) || !_isValidRepeatDay(candidate, repeat)) {
      candidate = _nextByRepeat(candidate, repeat);
    }

    if (forceFuture && !candidate.isAfter(now)) {
      candidate = _nextByRepeat(candidate, repeat);
      while (!_isValidRepeatDay(candidate, repeat) || !candidate.isAfter(now)) {
        candidate = _nextByRepeat(candidate, repeat);
      }
    }

    return candidate;
  }

  static DateTime _nextByRepeat(DateTime candidate, TaskRepeat repeat) {
    return switch (repeat) {
      TaskRepeat.none => candidate,
      TaskRepeat.daily => candidate.add(const Duration(days: 1)),
      TaskRepeat.weekdays => candidate.add(const Duration(days: 1)),
      TaskRepeat.weekly => candidate.add(const Duration(days: 7)),
    };
  }

  static bool _isValidRepeatDay(DateTime date, TaskRepeat repeat) {
    return switch (repeat) {
      TaskRepeat.none => true,
      TaskRepeat.daily => true,
      TaskRepeat.weekdays =>
        date.weekday >= DateTime.monday && date.weekday <= DateTime.friday,
      TaskRepeat.weekly => true,
    };
  }
}

class ParsedTime {
  const ParsedTime({required this.hour, required this.minute});

  final int hour;
  final int minute;
}
