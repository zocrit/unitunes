package io.github.zocrit.unitunes

import android.content.Intent
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
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

        publishSharingShortcuts()
        shareTargetType = resolveShareTarget(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getShareTargetType" -> result.success(shareTargetType)
                "getShareText" -> result.success(intent?.getStringExtra(Intent.EXTRA_TEXT))
                else -> result.notImplemented()
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
        setIntent(intent)
        shareTargetType = resolveShareTarget(intent)
        eventSink?.success(shareTargetType)
        super.onNewIntent(intent)
    }

    private fun publishSharingShortcuts() {
        val categories = setOf("io.github.zocrit.unitunes.category.MUSIC_SHARE")
        val icon = IconCompat.createWithResource(this, R.mipmap.ic_launcher)

        data class Target(val id: String, val labelRes: Int)

        val targets = listOf(
            Target("youtube_music", R.string.share_youtube_music),
            Target("tidal", R.string.share_tidal),
            Target("spotify", R.string.share_spotify),
        )

        val shortcuts = targets.map { target ->
            val person = Person.Builder()
                .setName(getString(target.labelRes))
                .setBot(true)
                .build()
            ShortcutInfoCompat.Builder(this, target.id)
                .setShortLabel(getString(target.labelRes))
                .setIcon(icon)
                .setIntent(Intent(Intent.ACTION_SEND).apply { type = "text/plain" })
                .setLongLived(true)
                .setCategories(categories)
                .setPerson(person)
                .build()
        }

        ShortcutManagerCompat.setDynamicShortcuts(this, shortcuts)
    }

    private fun resolveShareTarget(intent: Intent?): String {
        if (intent == null) return "youtube_music"
        val shortcutId = intent.getStringExtra(ShortcutManagerCompat.EXTRA_SHORTCUT_ID)
        if (shortcutId != null) return shortcutId
        val className = intent.component?.className ?: return "youtube_music"
        return when {
            className.contains("ShareToSpotify") -> "spotify"
            className.contains("ShareToTidal") -> "tidal"
            else -> "youtube_music"
        }
    }
}
