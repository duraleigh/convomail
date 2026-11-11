package com.clayaiken.precis

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Alerts on the phone.
 *
 * The helper sends a small message through Google's alert service when an
 * email needs you, a reminder comes due, or a "by" time is an hour away.
 * The phone draws the alert itself, so it can carry Done and Later, and so
 * the helper can take it away again when you deal with it somewhere else.
 *
 * Done and Later, pressed on an alert, go straight to the helper without
 * opening the app. If the phone has no signal at that moment the press is
 * kept, and sent the next time Précis opens.
 */
object Alerts {
    private const val PREFS = "precis.alerts"
    private const val NEEDS_YOU = "needs_you"
    private const val REMINDERS = "reminders"
    private const val QUIET = "quiet"
    const val ACTION = "com.clayaiken.precis.ALERT_ACTION"

    /** The key the app keeps this device's own key to the helper under. */
    private const val HELPER_TOKEN = "helper.token"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Makes Google's alert service ready, from the settings the helper
     * handed over when alerts were set up. Called when the app's process
     * starts for any reason, an arriving alert included. Returns whether
     * there was anything to make ready.
     */
    @Synchronized
    fun ready(context: Context): Boolean {
        val p = prefs(context)
        val appId = p.getString("appId", null) ?: return false
        if (FirebaseApp.getApps(context).isNotEmpty()) return true
        return try {
            FirebaseApp.initializeApp(
                context,
                FirebaseOptions.Builder()
                    .setApplicationId(appId)
                    .setApiKey(p.getString("apiKey", "")!!)
                    .setGcmSenderId(p.getString("senderId", "")!!)
                    .setProjectId(p.getString("projectId", "")!!)
                    .build()
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Signs this phone up for alerts and hands back its address for them. */
    fun start(context: Context, app: Map<String, String>, helper: String, done: (String?) -> Unit) {
        val p = prefs(context)
        val changed = p.getString("appId", null) != app["appId"] || p.getString("projectId", null) != app["projectId"]
        p.edit()
            .putString("appId", app["appId"]).putString("apiKey", app["apiKey"])
            .putString("senderId", app["senderId"]).putString("projectId", app["projectId"])
            .putString("helper", helper).apply()
        try {
            // A different Firebase project than before: start over with the new one.
            if (changed) FirebaseApp.getApps(context).forEach { it.delete() }
            if (!ready(context)) return done(null)
            channels(context)
            FirebaseMessaging.getInstance().token
                .addOnSuccessListener { token -> done(token) }
                .addOnFailureListener { done(null) }
        } catch (e: Exception) {
            done(null)
        }
    }

    /** Stops alerts on this phone and forgets what was needed for them. */
    fun stop(context: Context) {
        try {
            if (FirebaseApp.getApps(context).isNotEmpty()) FirebaseMessaging.getInstance().deleteToken()
        } catch (e: Exception) {
            // Nothing to take back.
        }
        prefs(context).edit().clear().apply()
        NotificationManagerCompat.from(context).cancelAll()
    }

    fun setRing(context: Context, ring: Boolean) = prefs(context).edit().putBoolean("ring", ring).apply()

    private fun channels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(NEEDS_YOU, "Needs you", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "An email that needs you, and a notice an hour before its time."
            setShowBadge(true)
        })
        manager.createNotificationChannel(NotificationChannel(REMINDERS, "Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "A reminder you set, at its time."
            setShowBadge(true)
        })
        manager.createNotificationChannel(NotificationChannel(QUIET, "During quiet hours", NotificationManager.IMPORTANCE_LOW).apply {
            description = "The same alerts during your quiet hours: they arrive without a sound."
            setShowBadge(true)
        })
    }

    /** Draws, replaces or takes away an alert, from what the helper sent. */
    fun show(context: Context, data: Map<String, String>) {
        val manager = NotificationManagerCompat.from(context)
        val id = data["id"]?.toIntOrNull() ?: return
        val kind = data["t"] ?: return
        if (kind == "clear") {
            manager.cancel(id)
            return
        }
        if (!prefs(context).getBoolean("ring", true) || !manager.areNotificationsEnabled()) return
        channels(context)
        val mid = data["mid"] ?: ""
        val uid = data["uid"] ?: ""
        val who = data["who"] ?: ""
        val ask = data["ask"] ?: ""
        val by = data["by"]?.toLongOrNull()
        val quiet = data["quiet"] == "1"
        val channel = if (quiet) QUIET else if (kind == "reminder") REMINDERS else NEEDS_YOU

        val title = when (kind) {
            "reminder" -> "Reminder"
            "due" -> if (who.isEmpty()) "Due within the hour" else "$who · due within the hour"
            else -> who.ifEmpty { "Précis" }
        }
        val text = if (by != null && kind != "reminder") "$ask · by ${clock(by)}" else ask

        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("mid", mid)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val builder = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_stat_precis)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(PendingIntent.getActivity(context, id, open, flags))
            .setAutoCancel(true)
            .setOnlyAlertOnce(kind != "due")
            .setCategory(if (kind == "reminder") NotificationCompat.CATEGORY_REMINDER else NotificationCompat.CATEGORY_EMAIL)
            .setPriority(if (quiet) NotificationCompat.PRIORITY_LOW else NotificationCompat.PRIORITY_HIGH)
            // What shows on the lock screen says only that something needs you, not what.
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
        data["n"]?.toIntOrNull()?.let { if (it > 0) builder.setNumber(it) }

        fun action(what: String, label: String, request: Int) {
            val press = Intent(context, AlertActionReceiver::class.java).apply {
                action = ACTION
                putExtra("what", what)
                putExtra("id", id)
                putExtra("mid", mid)
                putExtra("uid", uid)
            }
            builder.addAction(0, label, PendingIntent.getBroadcast(context, id * 4 + request, press, flags))
        }
        if (kind == "test") {
            // Nothing to act on.
        } else if (kind == "reminder") {
            if (uid.isNotEmpty()) action("reminder-done", "Done", 1)
        } else if (mid.isNotEmpty()) {
            action("done", "Done", 1)
            action("later", "Later (tomorrow)", 2)
        }
        try {
            manager.notify(id, builder.build())
        } catch (e: SecurityException) {
            // Alerts were turned off for Précis in the phone's settings.
        }
    }

    private fun clock(epochSeconds: Long): String = SimpleDateFormat("h:mm a", Locale.US).format(Date(epochSeconds * 1000))

    /** Tomorrow at 8 in the morning, by this phone's clock, in seconds. */
    private fun tomorrowMorning(): Long = Calendar.getInstance().apply {
        add(Calendar.DAY_OF_YEAR, 1)
        set(Calendar.HOUR_OF_DAY, 8)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis / 1000

    /** What Done or Later means, in the helper's words. */
    fun change(what: String, mid: String, uid: String): JSONObject? = when (what) {
        "done" -> JSONObject().put("kind", "done").put("k", mid).put("data", JSONObject().put("at", System.currentTimeMillis() / 1000))
        "later" -> JSONObject().put("kind", "msgfix").put("k", mid).put("data", JSONObject().put("later", tomorrowMorning()))
        "reminder-done" -> JSONObject().put("op", "reminder-done").put("uid", uid)
        else -> null
    }

    /**
     * Sends one change to the helper. "echo" asks the helper to say it back
     * to this phone too, so the app shows it the next time it opens.
     */
    fun send(context: Context, change: JSONObject): Boolean = post(context, "/api/push", JSONObject().put("items", JSONArray().put(change)).put("echo", true))

    /** Tells the helper this phone's new address for alerts. */
    fun sendAddress(context: Context, token: String): Boolean = post(context, "/api/devices/push", JSONObject().put("token", token))

    private fun post(context: Context, path: String, body: JSONObject): Boolean {
        val helper = prefs(context).getString("helper", null) ?: return false
        val token = Vault.read(context, HELPER_TOKEN) ?: return false
        if (!helper.startsWith("https://")) return false
        return try {
            val connection = URL(helper.trimEnd('/') + path).openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 8000
            connection.readTimeout = 8000
            connection.instanceFollowRedirects = false
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("X-Precis-Token", token)
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val ok = connection.responseCode in 200..299
            connection.disconnect()
            ok
        } catch (e: Exception) {
            false
        }
    }

    /** A press that could not be sent (no signal) waits here for the app. */
    @Synchronized
    fun keep(context: Context, change: JSONObject) {
        val p = prefs(context)
        val list = JSONArray(p.getString("waiting", "[]"))
        list.put(change)
        p.edit().putString("waiting", list.toString()).apply()
    }

    @Synchronized
    fun waiting(context: Context): String = prefs(context).getString("waiting", "[]") ?: "[]"

    @Synchronized
    fun clearWaiting(context: Context) = prefs(context).edit().remove("waiting").apply()
}

/** Receives what the helper sends through Google's alert service. */
class PrecisMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        Alerts.show(applicationContext, message.data)
    }

    override fun onNewToken(token: String) {
        // Google changed this phone's address for alerts: the helper is told.
        Thread { Alerts.sendAddress(applicationContext, token) }.start()
    }
}

/** Done or Later, pressed on an alert. */
class AlertActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Alerts.ACTION) return
        val app = context.applicationContext
        val change = Alerts.change(intent.getStringExtra("what") ?: "", intent.getStringExtra("mid") ?: "", intent.getStringExtra("uid") ?: "") ?: return
        NotificationManagerCompat.from(app).cancel(intent.getIntExtra("id", 0))
        val pending = goAsync()
        Thread {
            try {
                if (!Alerts.send(app, change)) Alerts.keep(app, change)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
