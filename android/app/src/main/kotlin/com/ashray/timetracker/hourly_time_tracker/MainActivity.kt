package com.ashray.timetracker.hourly_time_tracker

import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lets adb fire a sample hourly reminder; never registered in release builds.
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "time_tracker/debug")
            .setMethodCallHandler { call, result ->
                if (call.method != "takeTestReminderHour") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                // A one-shot file rather than an intent extra: Android replays a
                // task's original intent on later launches, which re-fired the test.
                val file = File(filesDir, TEST_HOUR_FILE)
                val hour = if (file.exists()) file.readText().trim().toIntOrNull() else null
                file.delete()
                result.success(hour?.takeIf { it in 0..23 })
            }
    }

    private companion object {
        const val TEST_HOUR_FILE = "test_reminder_hour"
    }
}
