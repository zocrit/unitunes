package io.github.zocrit.unitunes

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "io.github.zocrit.unitunes/share_target"
    private val EVENT_CHANNEL = "io.github.zocrit.unitunes/share_target_events"
    private var shareTargetType: String = "youtube_music"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        shareTargetType = resolveShareTarget(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getShareTargetType") {
                result.success(shareTargetType)
            } else {
                result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        shareTargetType = resolveShareTarget(intent)
        eventSink?.success(shareTargetType)
    }

    private fun resolveShareTarget(intent: Intent?): String {
        val className = intent?.component?.className ?: return "youtube_music"
        return when {
            className.contains("ShareToSpotify") -> "spotify"
            className.contains("ShareToTidal") -> "tidal"
            else -> "youtube_music"
        }
    }
}
