package com.example.hudyat

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // Text handed over by ShareActivity, held until the Dart side asks for it.
    private var pending: Map<String, String>? = null

    // The Dart call waiting on Android's SMS permission prompt.
    private var smsPermissionResult: MethodChannel.Result? = null
    private var notificationPermissionResult: MethodChannel.Result? = null
    private var receivePermissionResult: MethodChannel.Result? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROTECTION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(ProtectionEngine.status(this))
                    "requestSmsCapture" -> requestReceiveSms(result)
                    "setAppsOn" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        ProtectionEngine.setAppsOn(this, enabled)
                        if (enabled) ScamNotificationListener.instance?.baselineActive()
                        result.success(ProtectionEngine.status(this))
                    }
                    "setSourceEnabled" -> {
                        ProtectionEngine.setSourceEnabled(
                            this,
                            call.argument<String>("package") ?: "",
                            call.argument<Boolean>("enabled") == true,
                        )
                        result.success(ProtectionEngine.status(this))
                    }
                    "openNotificationAccess" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "openAlertSettings" -> {
                        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        result.success(null)
                    }
                    "stopAll" -> {
                        ProtectionEngine.stopAll(this)
                        result.success(ProtectionEngine.status(this))
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROTECTION_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    ProtectionEngine.resultsChanged = {
                        events?.success(mapOf("type" to "resultsChanged"))
                    }
                }

                override fun onCancel(arguments: Any?) {
                    ProtectionEngine.resultsChanged = null
                }
            })
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

    /** Uses the same serial worker as live capture. */
    private fun inBackground(result: MethodChannel.Result, work: () -> Unit) {
        ProtectionEngine.execute(this) {
            try {
                work()
                runOnUiThread { result.success(timedStatus()) }
            } catch (error: Exception) {
                runOnUiThread { result.error("check_failed", error.javaClass.simpleName, null) }
                throw error
            }
        }
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

    private fun requestReceiveSms(result: MethodChannel.Result) {
        if (ProtectionEngine.canCaptureSms(this)) {
            result.success(true)
            return
        }
        receivePermissionResult?.success(false)
        receivePermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), RECEIVE_REQUEST)
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
        if (requestCode == RECEIVE_REQUEST) {
            receivePermissionResult?.success(granted)
            receivePermissionResult = null
            return
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
            ACTION_RESULT -> mapOf(
                "open" to "result",
                "resultId" to intent.getLongExtra(EXTRA_RESULT_ID, -1).toString(),
            )
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
        const val PROTECTION_CHANNEL = "hudyat/protection"
        const val PROTECTION_EVENTS = "hudyat/protection_events"
        const val ACTION_FLAGGED = "com.example.hudyat.OPEN_FLAGGED"
        const val ACTION_RESULT = "com.example.hudyat.OPEN_RESULT"
        const val ACTION_CHECK = "com.example.hudyat.CHECK_MESSAGE"
        const val EXTRA_TEXT = "com.example.hudyat.TEXT"
        const val EXTRA_RESULT_ID = "com.example.hudyat.RESULT_ID"
        const val RECEIVE_REQUEST = 4203
    }
}
