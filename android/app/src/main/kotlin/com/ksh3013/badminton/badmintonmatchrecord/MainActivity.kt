package com.ksh3013.badminton.badmintonmatchrecord

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.BatteryManager
import android.os.StatFs
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject
import java.nio.charset.StandardCharsets

class MainActivity : FlutterActivity() {
    private val channelName = "rally/watch"
    private val recordingChannelName = "rally/recording"
    private val deviceChannelName = "rally/device"
    private var watchChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        watchChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        WatchBridgeStore.attach(applicationContext, watchChannel!!)
        watchChannel!!
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "state" -> sendWatchState(call.arguments, result)
                    "status" -> withConnectedNodes(result) { nodes ->
                        result.success(mapOf("connected" to nodes.isNotEmpty()))
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, recordingChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForeground" -> {
                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, RecordingForegroundService::class.java),
                        )
                        result.success(null)
                    }
                    "stopForeground" -> {
                        stopService(Intent(this, RecordingForegroundService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "health" -> {
                        val stat = StatFs(filesDir.path)
                        val battery = getSystemService(BATTERY_SERVICE) as BatteryManager
                        val capacity = battery.getIntProperty(
                            BatteryManager.BATTERY_PROPERTY_CAPACITY,
                        )
                        result.success(
                            mapOf(
                                "availableBytes" to stat.availableBytes,
                                "batteryPercent" to
                                    if (capacity in 0..100) capacity else null,
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun withConnectedNodes(result: MethodChannel.Result, callback: (List<Node>) -> Unit) {
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener(callback)
            .addOnFailureListener { callback(emptyList()) }
    }

    private fun sendWatchState(arguments: Any?, result: MethodChannel.Result) {
        val json = JSONObject()
        (arguments as? Map<*, *>)?.forEach { (key, value) ->
            if (key is String && value != null) json.put(key, value)
        }
        withConnectedNodes(result) { nodes ->
            if (nodes.isEmpty()) {
                result.success(mapOf("connected" to false))
                return@withConnectedNodes
            }
            val payload = json.toString().toByteArray(StandardCharsets.UTF_8)
            val messageClient = Wearable.getMessageClient(this)
            nodes.forEach { node ->
                messageClient.sendMessage(node.id, WatchBridgeStore.STATE_PATH, payload)
            }
            result.success(mapOf("connected" to true))
        }
    }

    override fun onDestroy() {
        watchChannel?.let(WatchBridgeStore::detach)
        watchChannel = null
        super.onDestroy()
    }
}
