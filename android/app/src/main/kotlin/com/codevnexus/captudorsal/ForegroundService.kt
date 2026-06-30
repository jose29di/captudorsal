package com.codevnexus.captudorsal

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.IBinder

class ForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = intent?.getParcelableExtra<Notification>("notification")
        val notificationId = intent?.getIntExtra("notificationId", 1) ?: 1

        if (notification != null) {
            startForeground(notificationId, notification)
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }
}
