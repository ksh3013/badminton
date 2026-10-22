package com.ksh3013.badminton.badmintonmatchrecord.watch

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.google.android.gms.wearable.Wearable

class MainActivity : Activity() {
    companion object {
        const val COMMAND_PATH = "/rally/command"
        const val STATE_PREFS = "rally_watch_state"
        private const val STATE_PATH = "/rally/state"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var connectionView: TextView
    private lateinit var statusView: TextView
    private lateinit var elapsedView: TextView
    private lateinit var progressView: TextView

    private val refreshTask = object : Runnable {
        override fun run() {
            refreshState()
            refreshConnection()
            mainHandler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildContent())
    }

    override fun onResume() {
        super.onResume()
        mainHandler.post(refreshTask)
    }

    override fun onPause() {
        mainHandler.removeCallbacks(refreshTask)
        super.onPause()
    }

    private fun buildContent(): View {
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(18, 14, 18, 18)
            setBackgroundColor(Color.rgb(16, 20, 17))
        }
        val scroll = ScrollView(this).apply {
            setBackgroundColor(Color.rgb(16, 20, 17))
            addView(content)
        }

        content.addView(label("RALLY", 20, Color.rgb(185, 243, 74)))
        connectionView = label("워치 연결 확인 중", 12, Color.LTGRAY)
        content.addView(connectionView)
        content.addView(spacer(10))

        statusView = label("상태 확인 중", 16, Color.WHITE)
        elapsedView = label("00:00", 28, Color.rgb(185, 243, 74))
        progressView = label("업로드 0%", 12, Color.LTGRAY)
        content.addView(statusView)
        content.addView(elapsedView)
        content.addView(progressView)
        content.addView(spacer(10))

        addCommandButton(content, "녹화 시작", "start")
        addCommandButton(content, "일시정지", "pause")
        addCommandButton(content, "녹화 재개", "resume")
        addCommandButton(content, "중요 장면", "marker")
        addCommandButton(content, "녹화 종료", "stop")
        return scroll
    }

    private fun addCommandButton(parent: LinearLayout, title: String, command: String) {
        val button = Button(this).apply {
            text = title
            isAllCaps = false
            setOnClickListener { sendCommand(command) }
        }
        parent.addView(
            button,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = 4 },
        )
    }

    private fun sendCommand(command: String) {
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                if (nodes.isEmpty()) {
                    connectionView.text = "휴대폰 연결 끊김"
                    return@addOnSuccessListener
                }
                connectionView.text = "휴대폰 연결됨"
                val payload = command.toByteArray(Charsets.UTF_8)
                val messages = Wearable.getMessageClient(this)
                nodes.forEach { node ->
                    messages.sendMessage(node.id, COMMAND_PATH, payload)
                }
            }
            .addOnFailureListener { connectionView.text = "휴대폰 연결 오류" }
    }

    private fun refreshConnection() {
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                connectionView.text = if (nodes.isEmpty()) {
                    "휴대폰 연결 끊김"
                } else {
                    "휴대폰 연결됨"
                }
            }
            .addOnFailureListener { connectionView.text = "휴대폰 연결 오류" }
    }

    private fun refreshState() {
        val state = getSharedPreferences(STATE_PREFS, MODE_PRIVATE)
        statusView.text = statusLabel(state.getString("status", "draft") ?: "draft")
        elapsedView.text = formatElapsed(state.getInt("elapsedSeconds", 0))
        progressView.text = "업로드 ${state.getInt("uploadProgress", 0)}%"
    }

    private fun statusLabel(status: String): String = when (status) {
        "recording" -> "녹화 중"
        "paused" -> "일시정지"
        "uploading" -> "업로드 중"
        "complete" -> "업로드 완료"
        else -> "시작 전"
    }

    private fun formatElapsed(seconds: Int): String =
        "%02d:%02d".format(seconds / 60, seconds % 60)

    private fun label(text: String, size: Int, color: Int): TextView = TextView(this).apply {
        this.text = text
        textSize = size.toFloat()
        setTextColor(color)
        gravity = Gravity.CENTER_HORIZONTAL
    }

    private fun spacer(height: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(1, height)
    }
}
