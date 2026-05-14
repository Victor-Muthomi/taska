import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ClockRuntimeService {
  const ClockRuntimeService();

  static const _channel = MethodChannel('taska/clock_runtime_service');

  Future<void> start() async {
    if (!_shouldUseAndroidForegroundService) {
      return;
    }
    await _channel.invokeMethod<void>('start');
  }

  Future<void> stop() async {
    if (!_shouldUseAndroidForegroundService) {
      return;
    }
    await _channel.invokeMethod<void>('stop');
  }

  bool get _shouldUseAndroidForegroundService =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
