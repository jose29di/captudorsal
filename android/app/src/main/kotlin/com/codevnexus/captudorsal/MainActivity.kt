package com.codevnexus.captudorsal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_BATTERY = "com.codevnexus.captudorsal/battery"
    private val CHANNEL_FOREGROUND = "com.codevnexus.captudorsal/foreground"
    private val CHANNEL_SOUND = "com.codevnexus.captudorsal/sound"
    private val CHANNEL_SCREEN = "com.codevnexus.captudorsal/screen"
    private val NOTIFICATION_CHANNEL_ID = "captudorsal_channel"
    private val NOTIFICATION_ID = 1

    private var toneGenerator: ToneGenerator? = null
    private var vibrator: Vibrator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Sound channel - native beep + vibration
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SOUND)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "beep" -> {
                        val durationMs = call.argument<Int>("duration") ?: 150
                        playBeep(durationMs)
                        result.success(true)
                    }
                    "doubleBeep" -> {
                        val durationMs = call.argument<Int>("duration") ?: 120
                        playDoubleBeep(durationMs)
                        result.success(true)
                    }
                    "vibrate" -> {
                        val durationMs = call.argument<Int>("duration") ?: 100
                        vibrate(durationMs.toLong())
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Screen brightness channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SCREEN)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dimScreen" -> {
                        dimScreen()
                        result.success(true)
                    }
                    "restoreBrightness" -> {
                        restoreBrightness()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_BATTERY)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestBatteryOptimizationExemption" -> {
                        result.success(requestBatteryExemption())
                    }
                    "isBatteryOptimizationEnabled" -> {
                        result.success(isBatteryOptimizationEnabled())
                    }
                    else -> result.notImplemented()
                }
            }

        // Foreground service channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_FOREGROUND)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        val title = call.argument<String>("title") ?: "CaptuDorsal"
                        val message = call.argument<String>("message") ?: "Procesando dorsales..."
                        startForegroundService(title, message)
                        result.success(true)
                    }
                    "updateNotification" -> {
                        val title = call.argument<String>("title")
                        val message = call.argument<String>("message")
                        updateNotification(title, message)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        stopForegroundService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestBatteryExemption(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            }
        }
        return true
    }

    private fun isBatteryOptimizationEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            return !powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return false
    }

    private fun startForegroundService(title: String, message: String) {
        createNotificationChannel()

        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(Intent(this, ForegroundService::class.java).apply {
                putExtra("notification", notification)
                putExtra("notificationId", NOTIFICATION_ID)
            })
        }
    }

    private fun updateNotification(title: String?, message: String?) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title ?: "CaptuDorsal")
            .setContentText(message ?: "Procesando dorsales...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun stopForegroundService() {
        stopService(Intent(this, ForegroundService::class.java))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "CaptuDorsal Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notificación del servicio de procesamiento de dorsales"
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun playBeep(durationMs: Int) {
        try {
            vibrate(80)
            if (toneGenerator == null) {
                toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
            }
            val toneType = android.media.ToneGenerator.TONE_PROP_BEEP
            toneGenerator?.startTone(toneType, durationMs)
        } catch (e: Exception) {
            try {
                val tg = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
                tg.startTone(android.media.ToneGenerator.TONE_PROP_BEEP, durationMs)
            } catch (_: Exception) {}
        }
    }

    private fun playDoubleBeep(durationMs: Int) {
        vibrate(60)
        Thread {
            try {
                if (toneGenerator == null) {
                    toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                }
                toneGenerator?.startTone(android.media.ToneGenerator.TONE_PROP_BEEP, durationMs)
                Thread.sleep((durationMs + 100).toLong())
                toneGenerator?.startTone(android.media.ToneGenerator.TONE_PROP_BEEP, durationMs)
            } catch (_: Exception) {}
        }.start()
    }

    private fun vibrate(durationMs: Long) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibrator = vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(durationMs)
            }
        } catch (_: Exception) {}
    }

    private fun dimScreen() {
        try {
            val params = window.attributes
            params.screenBrightness = 0.0f
            window.attributes = params
        } catch (e: Exception) {}
    }

    private fun restoreBrightness() {
        try {
            val params = window.attributes
            params.screenBrightness = -1.0f
            window.attributes = params
        } catch (e: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        toneGenerator?.release()
        toneGenerator = null
    }
}
