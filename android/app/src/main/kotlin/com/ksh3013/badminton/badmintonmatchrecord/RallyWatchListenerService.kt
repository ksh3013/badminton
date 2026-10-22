package com.ksh3013.badminton.badmintonmatchrecord

import android.content.Intent
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject
import java.nio.charset.StandardCharsets

class RallyWatchListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != WatchBridgeStore.COMMAND_PATH) return
        val raw = String(event.data, StandardCharsets.UTF_8).trim()
        val command = if (raw.startsWith("{")) {
            JSONObject(raw).optString("value")
        } else {
            raw
        }
        WatchBridgeStore.dispatch(this, command)
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
    }
}
