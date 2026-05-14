package com.taska.app.taska

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "taska/clock_runtime_service",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    ClockRuntimeForegroundService.start(this)
                    result.success(null)
                }
                "stop" -> {
                    ClockRuntimeForegroundService.stop(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
