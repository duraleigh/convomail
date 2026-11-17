package com.clayaiken.precis

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * "Share" in another app, with Précis picked. Shows nothing itself: it takes
 * what was shared, keeps a copy of any files (the other app only lends them
 * while this is open), and opens Précis on a new email with it all.
 */
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val from = intent
        // Brought back by Android itself, not by a share: there is nothing to take.
        if (savedInstanceState != null || from == null || from.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) {
            finish()
            return
        }
        val app = applicationContext
        Thread {
            val json = try {
                Shared.read(app, from)
            } catch (e: Exception) {
                null
            }
            runOnUiThread {
                if (json != null) {
                    Shared.put(json)
                    startActivity(Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra(Shared.EXTRA, true)
                    })
                }
                finish()
            }
        }.start()
    }
}

/** What another app shared, read into Précis's own words and space. */
object Shared {
    /** On the intent that opens the app's screen: something shared is waiting. */
    const val EXTRA = "share"

    /** More words than any email holds; past this the rest is left off. */
    private const val MAX_TEXT = 200_000

    /** Mail services turn away an email much over 25 MB, so more is not copied. */
    private const val MAX_BYTES = 30L * 1024 * 1024
    private const val MAX_FILES = 50
    private const val KEEP_DAYS = 30L

    private var waiting: String? = null

    @Synchronized
    fun put(json: String) {
        waiting = json
    }

    /** What is waiting, once. */
    @Synchronized
    fun take(): String? = waiting.also { waiting = null }

    /**
     * The shared text, subject and files as JSON, or null when the intent is
     * not a share. Files are copied into the app's own space; "skipped" says
     * how many could not be read and "big" how many were left out for size.
     */
    fun read(context: Context, intent: Intent): String? {
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return null

        val out = JSONObject()
        out.put("text", text(intent).take(MAX_TEXT))
        out.put("subject", (intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: "").take(500))

        val files = JSONArray()
        var skipped = 0
        var big = 0
        val uris = uris(intent)
        if (uris.isNotEmpty()) {
            val home = File(context.cacheDir, "shared")
            clean(home)
            val dir = File(home, System.currentTimeMillis().toString())
            var room = MAX_BYTES
            val taken = HashSet<String>()
            for ((n, uri) in uris.withIndex()) {
                // Only what another app hands over. Never a plain file path,
                // and never something of Précis's own: a share must not be
                // able to point Précis at its private files.
                if (n >= MAX_FILES || uri.scheme != "content" || (uri.authority ?: "").startsWith(context.packageName)) {
                    skipped++
                    continue
                }
                try {
                    val type = context.contentResolver.getType(uri)
                    val name = unique(name(context, uri, type, n + 1), taken)
                    dir.mkdirs()
                    val to = File(dir, name)
                    val copied = copy(context, uri, to, room)
                    if (copied < 0) {
                        to.delete()
                        big++
                    } else {
                        room -= copied
                        files.put(to.absolutePath)
                    }
                } catch (e: Exception) {
                    skipped++
                }
            }
        }
        out.put("files", files)
        out.put("skipped", skipped)
        out.put("big", big)
        return out.toString()
    }

    /** The shared words. Several pieces (a share of several things) are set one under another. */
    private fun text(intent: Intent): String {
        val one = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
        if (one != null) return one.toString()
        val many = try {
            intent.getCharSequenceArrayListExtra(Intent.EXTRA_TEXT)
        } catch (e: Exception) {
            null
        }
        return many?.filterNotNull()?.joinToString("\n\n") { it.toString() } ?: ""
    }

    @Suppress("DEPRECATION")
    private fun uris(intent: Intent): List<Uri> {
        val found = ArrayList<Uri>()
        try {
            if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.filterNotNull()?.let { found.addAll(it) }
            } else {
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { found.add(it) }
            }
        } catch (e: Exception) {
            // Not addresses of files after all.
        }
        // Some apps name the files only here.
        if (found.isEmpty()) {
            val clip = intent.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) clip.getItemAt(i)?.uri?.let { found.add(it) }
            }
        }
        return found.distinct()
    }

    /** The file's own name, made safe to keep, with an ending that says what it is. */
    private fun name(context: Context, uri: Uri, type: String?, number: Int): String {
        var name = ""
        try {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) name = c.getString(0) ?: ""
            }
        } catch (e: Exception) {
            // Named below.
        }
        name = name.substringAfterLast('/').substringAfterLast('\\').replace(Regex("[\\u0000-\\u001f<>:\"|?*]"), " ").trim().trimStart('.')
        if (name.length > 120) {
            val end = name.substringAfterLast('.', "")
            name = if (end.isNotEmpty() && end.length <= 8) name.take(120 - end.length - 1).trim() + "." + end else name.take(120).trim()
        }
        val ending = MimeTypeMap.getSingleton().getExtensionFromMimeType(type ?: "")
        if (name.isEmpty()) name = "shared-$number"
        if (!name.contains('.') && !ending.isNullOrEmpty()) name = "$name.$ending"
        return name
    }

    private fun unique(name: String, taken: MutableSet<String>): String {
        var n = name
        var i = 2
        while (!taken.add(n.lowercase())) {
            val dot = name.lastIndexOf('.')
            n = if (dot > 0) name.substring(0, dot) + " ($i)" + name.substring(dot) else "$name ($i)"
            i++
        }
        return n
    }

    /** Copies the file; the number of bytes, or -1 when it is more than [room]. */
    private fun copy(context: Context, uri: Uri, to: File, room: Long): Long {
        var total = 0L
        val input = context.contentResolver.openInputStream(uri) ?: throw IllegalStateException("could not be opened")
        input.use { i ->
            to.outputStream().use { o ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val got = i.read(buffer)
                    if (got < 0) break
                    total += got
                    if (total > room) return -1
                    o.write(buffer, 0, got)
                }
            }
        }
        return total
    }

    /** Copies from long ago are thrown out; an email not sent by then lists the file as gone. */
    private fun clean(home: File) {
        val old = System.currentTimeMillis() - KEEP_DAYS * 24 * 60 * 60 * 1000
        try {
            home.listFiles()?.forEach { if (it.lastModified() < old) it.deleteRecursively() }
        } catch (e: Exception) {
            // Tried again at the next share.
        }
    }
}
