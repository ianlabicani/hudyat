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
    private var notificationPermissionResult: MethodChannel.Result? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, POWER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Back on the first screen: leave the app running instead of
                    // closing it, so it can go on checking messages.
                    "toBackground" -> result.success(moveTaskToBack(true))
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIMED_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(timedStatus())
                    "requestNotifications" -> requestNotifications(result)
                    "turnOn" -> inBackground(result) {
                        InboxCheck.setOn(this, true)
                        // Texts already in the inbox are counted, not alerted.
                        InboxCheck.run(applicationContext, alert = false)
                        InboxAlarm.sync(this)
                    }
                    "turnOff" -> {
                        InboxCheck.setOn(this, false)
                        InboxAlarm.sync(this)
                        result.success(timedStatus())
                    }
                    "checkNow" -> inBackground(result) {
                        InboxCheck.run(applicationContext, alert = InboxCheck.isOn(this))
                    }
                    else -> result.notImplemented()
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

    private fun timedStatus(): Map<String, Any> {
        val counts = InboxCheck.counts(this)
        return mapOf(
            "on" to InboxCheck.isOn(this),
            "state" to counts.state,
            "scam" to counts.scam,
            "caution" to counts.caution,
            "gambling" to counts.gambling,
            "total" to counts.total,
            "checkedAt" to counts.checkedAt,
            "canNotify" to InboxCheck.canNotify(this),
            "intervalMinutes" to InboxAlarm.intervalMinutes(this),
        )
    }

    /** Runs [work] off the main thread, then answers with the new status. */
    private fun inBackground(result: MethodChannel.Result, work: () -> Unit) {
        Thread {
            work()
            runOnUiThread { result.success(timedStatus()) }
        }.start()
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (InboxCheck.canNotify(this)) {
            result.success(true)
            return
        }
        notificationPermissionResult?.success(false)
        notificationPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFY_REQUEST)
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
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        if (requestCode == NOTIFY_REQUEST) {
            notificationPermissionResult?.success(granted)
            notificationPermissionResult = null
        }
        if (requestCode != SMS_REQUEST) return
        smsPermissionResult?.success(granted)
        smsPermissionResult = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        capture(intent, notify = false)
        InboxAlarm.sync(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        capture(intent, notify = true)
    }

    private fun capture(intent: Intent?, notify: Boolean) {
        pending = when (intent?.action) {
            ACTION_CHECK -> mapOf("text" to (intent.getStringExtra(EXTRA_TEXT) ?: ""))
            // A tap on a scam alert or on the widget.
            ACTION_FLAGGED -> mapOf("open" to "flagged")
            else -> return
        }
        // So the same text is not checked again if the activity is restored.
        intent.action = Intent.ACTION_MAIN
        if (notify) channel?.invokeMethod("incoming", null)
    }

    companion object {
        const val CHANNEL = "hudyat/incoming"
        const val SMS_CHANNEL = "hudyat/sms"
        const val POWER_CHANNEL = "hudyat/power"
        const val SMS_REQUEST = 4201
        const val NOTIFY_REQUEST = 4202
        const val TIMED_CHANNEL = "hudyat/timed"
        const val ACTION_FLAGGED = "com.example.hudyat.OPEN_FLAGGED"
        const val ACTION_CHECK = "com.example.hudyat.CHECK_MESSAGE"
        const val EXTRA_TEXT = "com.example.hudyat.TEXT"
    }
}
