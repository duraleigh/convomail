package com.clayaiken.precis

import android.Manifest
import android.app.Application
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Makes Google's alert service ready whenever the app's process starts, an arriving alert included. */
class PrecisApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Alerts.ready(this)
    }
}

/**
 * The app's one screen, and the few things only Android can do for it:
 * keep secrets locked, and handle alerts.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var askResult: MethodChannel.Result? = null

    /** The email whose alert was tapped, until the app asks for it. */
    private var opened: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        opened = intent?.getStringExtra("mid")?.takeIf { it.isNotEmpty() }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "precis/android").also { it.setMethodCallHandler(::handle) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val mid = intent.getStringExtra("mid")?.takeIf { it.isNotEmpty() } ?: return
        opened = mid
        channel?.invokeMethod("opened", mid)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val app = applicationContext
        try {
            when (call.method) {
                "vaultRead" -> result.success(Vault.read(app, call.argument<String>("key")!!))
                "vaultWrite" -> {
                    Vault.write(app, call.argument<String>("key")!!, call.argument<String>("value")!!)
                    result.success(null)
                }
                "vaultDelete" -> {
                    Vault.delete(app, call.argument<String>("key")!!)
                    result.success(null)
                }
                "alertsAllowed" -> result.success(NotificationManagerCompat.from(app).areNotificationsEnabled())
                "alertsAsk" -> askForAlerts(result)
                "alertsStart" -> {
                    val settings = call.argument<Map<String, String>>("app") ?: emptyMap()
                    Alerts.start(app, settings, call.argument<String>("helper") ?: "") { token -> runOnUiThread { result.success(token) } }
                }
                "alertsStop" -> {
                    Alerts.stop(app)
                    result.success(null)
                }
                "alertsRing" -> {
                    Alerts.setRing(app, call.argument<Boolean>("ring") ?: true)
                    result.success(null)
                }
                "alertsWaiting" -> result.success(Alerts.waiting(app))
                "alertsClearWaiting" -> {
                    Alerts.clearWaiting(app)
                    result.success(null)
                }
                "alertsClearShown" -> {
                    NotificationManagerCompat.from(app).cancelAll()
                    result.success(null)
                }
                "playSent" -> {
                    // Précis's own short sound for "your message has gone".
                    val player = android.media.MediaPlayer.create(
                        app,
                        R.raw.sent,
                        android.media.AudioAttributes.Builder()
                            .setUsage(android.media.AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                        (app.getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager).generateAudioSessionId()
                    )
                    player?.setOnCompletionListener { it.release() }
                    player?.start()
                    result.success(null)
                }
                "takeOpened" -> {
                    result.success(opened)
                    opened = null
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("precis", e.message, null)
        }
    }

    /** Android 13 and later ask the owner before an app may show alerts. */
    private fun askForAlerts(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
            return
        }
        askResult?.success(false)
        askResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4711)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 4711) return
        askResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        askResult = null
    }
}
