import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ClockRuntimeState {
  const ClockRuntimeState({
    required this.nextAlarmId,
    required this.alarms,
    required this.timerDurationSeconds,
    this.timerEndsAtUtcIso,
  });

  factory ClockRuntimeState.initial() {
    return const ClockRuntimeState(
      nextAlarmId: 1,
      alarms: <StoredClockAlarm>[],
      timerDurationSeconds: 300,
    );
  }

  factory ClockRuntimeState.fromJson(Map<String, dynamic> json) {
    return ClockRuntimeState(
      nextAlarmId: (json['nextAlarmId'] as num?)?.toInt() ?? 1,
      alarms: ((json['alarms'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StoredClockAlarm.fromJson)
          .toList(growable: false),
      timerDurationSeconds:
          (json['timerDurationSeconds'] as num?)?.toInt() ?? 300,
      timerEndsAtUtcIso: json['timerEndsAtUtcIso'] as String?,
    );
  }

  final int nextAlarmId;
  final List<StoredClockAlarm> alarms;
  final int timerDurationSeconds;
  final String? timerEndsAtUtcIso;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nextAlarmId': nextAlarmId,
      'alarms': alarms.map((alarm) => alarm.toJson()).toList(growable: false),
      'timerDurationSeconds': timerDurationSeconds,
      'timerEndsAtUtcIso': timerEndsAtUtcIso,
    };
  }
}

class StoredClockAlarm {
  const StoredClockAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.nextRingAtUtcIso,
    required this.enabled,
  });

  factory StoredClockAlarm.fromJson(Map<String, dynamic> json) {
    return StoredClockAlarm(
      id: (json['id'] as num?)?.toInt() ?? 0,
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      nextRingAtUtcIso:
          json['nextRingAtUtcIso'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  final int id;
  final int hour;
  final int minute;
  final String nextRingAtUtcIso;
  final bool enabled;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'hour': hour,
      'minute': minute,
      'nextRingAtUtcIso': nextRingAtUtcIso,
      'enabled': enabled,
    };
  }
}

class ClockRuntimeStorage {
  const ClockRuntimeStorage();

  static const _fileName = 'taska_clock_runtime_state.json';

  Future<ClockRuntimeState> load() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) {
        return ClockRuntimeState.initial();
      }
      final source = await file.readAsString();
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic>) {
        return ClockRuntimeState.initial();
      }
      return ClockRuntimeState.fromJson(json);
    } catch (_) {
      return ClockRuntimeState.initial();
    }
  }

  Future<void> save(ClockRuntimeState state) async {
    final file = await _stateFile();
    await file.writeAsString(jsonEncode(state.toJson()));
  }

  Future<File> _stateFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }
}
