package com.example.hudyat

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // Text handed over by ShareActivity, held until the Dart side asks for it.
    private var pending: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        capture(intent, notify = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        capture(intent, notify = true)
    }

    private fun capture(intent: Intent?, notify: Boolean) {
        if (intent?.action != ACTION_CHECK) return
        pending = mapOf("text" to (intent.getStringExtra(EXTRA_TEXT) ?: ""))
        // So the same text is not checked again if the activity is restored.
        intent.action = Intent.ACTION_MAIN
        if (notify) channel?.invokeMethod("incoming", null)
    }

    companion object {
        const val CHANNEL = "hudyat/incoming"
        const val ACTION_CHECK = "com.example.hudyat.CHECK_MESSAGE"
        const val EXTRA_TEXT = "com.example.hudyat.TEXT"
    }
}
