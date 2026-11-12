package com.clayaiken.precis

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PersistableBundle
import android.widget.Toast
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
    private const val CODES = "codes"
    private const val KNOW = "good_to_know"
    private const val CHATS = "chats"
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

    /** How alerts write a time: 15:00 when true, 3:00 PM when not. */
    fun setClock24(context: Context, h24: Boolean) = prefs(context).edit().putBoolean("h24", h24).apply()

    private fun channels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        // One channel for each kind of alert, so each can be turned off or
        // given its own sound in the phone's settings for Précis.
        manager.createNotificationChannel(NotificationChannel(NEEDS_YOU, "Needs you", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "An email that needs you, and a notice an hour before its time."
            setShowBadge(true)
        })
        manager.createNotificationChannel(NotificationChannel(KNOW, "Good to know", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Something worth knowing that asks nothing of you: an answer you were waiting for, news about your own orders, accounts and bookings."
            setShowBadge(true)
        })
        manager.createNotificationChannel(NotificationChannel(CHATS, "Chats", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "A new email from a person, when it does not need you."
            setShowBadge(true)
        })
        manager.createNotificationChannel(NotificationChannel(REMINDERS, "Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "A reminder you set, at its time."
            setShowBadge(true)
        })
        manager.createNotificationChannel(NotificationChannel(CODES, "OTP", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "A sign-in code that just came by email: the code, ready to paste."
            setShowBadge(false)
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
        val h24 = prefs(context).getBoolean("h24", false)
        val ask = timesInText(data["ask"] ?: "", h24)
        val by = data["by"]?.toLongOrNull()
        val quiet = data["quiet"] == "1"
        if (kind == "code") {
            showCode(context, id, mid, who, data["code"] ?: "", data["until"]?.toLongOrNull(), quiet)
            return
        }
        val channel = if (quiet) QUIET else when (kind) {
            "reminder" -> REMINDERS
            "know" -> KNOW
            "chat" -> CHATS
            else -> NEEDS_YOU
        }

        val title = when (kind) {
            "reminder" -> "Reminder"
            "due" -> if (who.isEmpty()) "Due within the hour" else "$who · due within the hour"
            else -> who.ifEmpty { "Précis" }
        }
        val text = if (by != null && kind != "reminder") "$ask · by ${clock(by, h24)}" else ask

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
        if (kind == "test" || kind == "know" || kind == "chat") {
            // Nothing to act on: a tap opens it.
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

    /**
     * A sign-in code: who sent it and the code itself, already copied, with
     * Copy to copy it again. It goes away by itself when the code is no good.
     */
    private fun showCode(context: Context, id: Int, mid: String, who: String, code: String, until: Long?, quiet: Boolean) {
        if (code.isEmpty()) return
        val copied = copy(context, code)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val open = Intent(context, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("mid", mid)
        }
        val press = Intent(context, AlertActionReceiver::class.java).apply {
            action = ACTION
            putExtra("what", "copy")
            putExtra("id", id)
            putExtra("code", code)
        }
        val title = if (who.isEmpty()) "Sign-in code" else "$who · sign-in code"
        val text = if (copied) "$code · copied, ready to paste" else code
        val builder = NotificationCompat.Builder(context, if (quiet) QUIET else CODES)
            .setSmallIcon(R.drawable.ic_stat_precis)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(PendingIntent.getActivity(context, id, open, flags))
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(if (quiet) NotificationCompat.PRIORITY_LOW else NotificationCompat.PRIORITY_HIGH)
            // On a locked phone it says a code came, not what the code is.
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(
                NotificationCompat.Builder(context, if (quiet) QUIET else CODES)
                    .setSmallIcon(R.drawable.ic_stat_precis)
                    .setContentTitle(title)
                    .setContentText("Unlock to see it")
                    .build()
            )
            .addAction(0, "Copy", PendingIntent.getBroadcast(context, id * 4 + 3, press, flags))
        if (until != null) {
            val left = until * 1000 - System.currentTimeMillis()
            if (left <= 0) return
            builder.setTimeoutAfter(left)
        }
        try {
            NotificationManagerCompat.from(context).notify(id, builder.build())
        } catch (e: SecurityException) {
            // Alerts were turned off for Précis in the phone's settings.
        }
    }

    /** Puts a code on the phone's clipboard, marked private so it is not shown in previews. */
    fun copy(context: Context, code: String): Boolean = try {
        val clip = ClipData.newPlainText("Sign-in code", code)
        if (Build.VERSION.SDK_INT >= 24) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean(if (Build.VERSION.SDK_INT >= 33) ClipDescription.EXTRA_IS_SENSITIVE else "android.content.extra.IS_SENSITIVE", true)
            }
        }
        (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(clip)
        true
    } catch (e: Exception) {
        false
    }

    private fun clock(epochSeconds: Long, h24: Boolean): String = SimpleDateFormat(if (h24) "HH:mm" else "h:mm a", Locale.US).format(Date(epochSeconds * 1000))

    private val twelve = Regex("\\b(1[0-2]|0?[1-9])(?::([0-5]\\d))?\\s?(?:([AaPp])[Mm]\\b|([AaPp])\\.[Mm]\\.)")
    private val twentyFour = Regex("(?<![\\d:.])(0\\d|1[3-9]|2[0-3]):([0-5]\\d)(?![\\d:])(?!\\s?[AaPp]\\.?[Mm])")

    /** The clock times inside the assistant's words, written the way the user reads the clock. */
    fun timesInText(text: String, h24: Boolean): String = if (h24) {
        twelve.replace(text) { m ->
            var h = m.groupValues[1].toInt() % 12
            if ((m.groupValues[3] + m.groupValues[4]).lowercase() == "p") h += 12
            "%02d:%s".format(h, m.groupValues[2].ifEmpty { "00" })
        }
    } else {
        twentyFour.replace(text) { m ->
            val h = m.groupValues[1].toInt()
            "%d:%s %s".format(if (h % 12 == 0) 12 else h % 12, m.groupValues[2], if (h < 12) "AM" else "PM")
        }
    }

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
        if (intent.getStringExtra("what") == "copy") {
            // Copy on a sign-in code: copied again, and the alert stays.
            val ok = Alerts.copy(app, intent.getStringExtra("code") ?: "")
            if (Build.VERSION.SDK_INT < 33) Toast.makeText(app, if (ok) "Code copied" else "Could not copy the code", Toast.LENGTH_SHORT).show()
            return
        }
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
