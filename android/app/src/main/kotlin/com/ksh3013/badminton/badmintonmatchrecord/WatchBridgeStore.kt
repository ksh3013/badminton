package com.ksh3013.badminton.badmintonmatchrecord

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

/** Keeps watch commands until the Flutter engine is ready to receive them. */
object WatchBridgeStore {
    const val COMMAND_PATH = "/rally/command"
    const val STATE_PATH = "/rally/state"

    private const val PREFS = "rally_watch_bridge"
    private const val PENDING_COMMANDS = "pending_commands"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    @Synchronized
    fun attach(context: Context, nextChannel: MethodChannel) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        channel = nextChannel
        drain(context)
    }

    @Synchronized
    fun detach(previousChannel: MethodChannel) {
        if (channel == previousChannel) channel = null
    }

    fun dispatch(context: Context, command: String) {
        if (command !in setOf("start", "pause", "resume", "stop", "marker")) return
        val current = synchronized(this) { channel }
        if (current == null) {
            enqueue(context, command)
            return
        }
        mainHandler.post {
            synchronized(this) { channel }?.invokeMethod(
                "command",
                mapOf("value" to command),
            )
        }
    }

    private fun drain(context: Context) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = try {
            JSONArray(preferences.getString(PENDING_COMMANDS, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        preferences.edit().remove(PENDING_COMMANDS).apply()
        for (index in 0 until pending.length()) {
            val command = pending.optString(index)
            if (command.isNotEmpty()) {
                mainHandler.post {
                    synchronized(this) { channel }?.invokeMethod(
                        "command",
                        mapOf("value" to command),
                    )
                }
            }
        }
    }

    private fun enqueue(context: Context, command: String) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = try {
            JSONArray(preferences.getString(PENDING_COMMANDS, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        pending.put(command)
        preferences.edit().putString(PENDING_COMMANDS, pending.toString()).apply()
    }
}
