package com.example.hudyat

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // Text handed over by ShareActivity, held until the Dart side asks for it.
    private var pending: Map<String, String>? = null

    // The Dart call waiting on Android's SMS permission prompt.
    private var smsPermissionResult: MethodChannel.Result? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(canReadSms())
                    "requestPermission" -> requestSms(result)
                    "read" -> {
                        if (!canReadSms()) {
                            result.error("no_permission", "SMS access is not granted", null)
                        } else {
                            try {
                                result.success(
                                    SmsReader.read(
                                        this,
                                        (call.argument<Number>("since") ?: 0).toLong(),
                                        (call.argument<Number>("afterId") ?: 0).toLong(),
                                        (call.argument<Number>("limit") ?: 200).toInt(),
                                    ),
                                )
                            } catch (error: Exception) {
                                result.error("read_failed", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canReadSms(): Boolean =
        checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    private fun requestSms(result: MethodChannel.Result) {
        if (canReadSms()) {
            result.success(true)
            return
        }
        // Answer an earlier, unanswered request so its caller is not left waiting.
        smsPermissionResult?.success(false)
        smsPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.READ_SMS), SMS_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SMS_REQUEST) return
        smsPermissionResult?.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
        )
        smsPermissionResult = null
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
        const val SMS_CHANNEL = "hudyat/sms"
        const val SMS_REQUEST = 4201
        const val ACTION_CHECK = "com.example.hudyat.CHECK_MESSAGE"
        const val EXTRA_TEXT = "com.example.hudyat.TEXT"
    }
}
