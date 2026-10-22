package com.ksh3013.badminton.badmintonmatchrecord.watch

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject
import java.nio.charset.StandardCharsets

class RallyWatchListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != "/rally/state") return
        val state = try {
            JSONObject(String(event.data, StandardCharsets.UTF_8))
        } catch (_: Exception) {
            return
        }
        getSharedPreferences(MainActivity.STATE_PREFS, MODE_PRIVATE).edit()
            .putString("status", state.optString("status", "draft"))
            .putInt("elapsedSeconds", state.optInt("elapsedSeconds", 0))
            .putInt("uploadProgress", state.optInt("uploadProgress", 0))
            .apply()
    }
}
