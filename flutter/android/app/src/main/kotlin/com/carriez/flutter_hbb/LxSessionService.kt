package com.carriez.flutter_hbb

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Eigene Anpassung: Hält die App während einer ausgehenden Fernsteuerung als
 * Vordergrunddienst aktiv. Ohne das friert Android die App kurz nach dem
 * Wechsel in eine andere App ein, die Verbindung bricht ab und der
 * Wiederaufbau scheitert beim Zurückkehren.
 */
class LxSessionService : Service() {
    companion object {
        private const val TAG = "LxSessionService"
        private const val CHANNEL_ID = "LxSession"
        private const val NOTIFY_ID = 4711

        fun start(context: Context) {
            val intent = Intent(context, LxSessionService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.w(TAG, "start failed: $e")
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, LxSessionService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "stop failed: $e")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Aktive Fernsteuerung",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_stat_logo)
            .setContentTitle("RustDesk lx")
            .setContentText("Fernsteuerung aktiv – die Verbindung bleibt im Hintergrund bestehen.")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(PendingIntent.getActivity(this, 1, open, piFlags))
            .setColor(ContextCompat.getColor(this, R.color.primary))
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFY_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFY_ID, notification)
            }
        } catch (e: Exception) {
            Log.w(TAG, "startForeground failed: $e")
            stopSelf()
        }
        return START_NOT_STICKY
    }

    // App aus der Übersicht weggewischt: Dienst beenden, keine verwaiste Verbindung.
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }
}
