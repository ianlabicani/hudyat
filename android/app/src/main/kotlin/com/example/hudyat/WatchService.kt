package com.example.hudyat

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app awake while automatic checking is on. Without a foreground
 * service the phone freezes the app seconds after it leaves the screen, and
 * a frozen app only sees a message once it is opened again. The service does
 * no work itself; its ongoing notification is what tells the user, and the
 * system, that Hudyat is still checking.
 */
class WatchService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Automatic checking", NotificationManager.IMPORTANCE_LOW),
        )
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(this, CHANNEL)
            .setContentTitle("Hudyat is checking incoming messages")
            .setContentText("Sinusuri ang mga dumarating na mensahe. Nothing leaves this phone.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(open)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ID, notification)
        }
        return START_STICKY
    }

    companion object {
        const val CHANNEL = "automatic_checking"
        const val ID = 4202
    }
}
