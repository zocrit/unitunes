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

        shareTargetType = if (intent?.component?.className?.contains("ShareToTidal") == true)
            "tidal" else "youtube_music"

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
        shareTargetType = if (intent.component?.className?.contains("ShareToTidal") == true)
            "tidal" else "youtube_music"
        eventSink?.success(shareTargetType)
    }
}
