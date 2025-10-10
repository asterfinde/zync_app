package com.datainfers.zync

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "mini_emoji/notification"
    private val NOTIFICATION_ID = 12345
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 100

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success("Permisos solicitados")
                }
                "showNotification" -> {
                    if (hasNotificationPermission()) {
                        showPersistentNotification()
                        result.success("Notificación mostrada")
                    } else {
                        result.error("NO_PERMISSION", "Permisos de notificación requeridos", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("open_emoji_modal", false)) {
            // Enviar a Flutter para abrir modal
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                val channel = MethodChannel(messenger, CHANNEL)
                channel.invokeMethod("showEmojiModal", null)
            }
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            // En versiones anteriores a Android 13, los permisos se otorgan automáticamente
            true
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!hasNotificationPermission()) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE
                )
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            NOTIFICATION_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    // Permisos otorgados, podemos mostrar notificaciones
                    showPersistentNotification()
                } else {
                    // Permisos denegados
                    println("❌ Permisos de notificación denegados")
                }
            }
        }
    }

    private fun showPersistentNotification() {
        createNotificationChannel()
        
        // Point 15: Usar StatusModalActivity en lugar de MainActivity
        // Esto evita abrir la app completa, solo el modal transparente
        val intent = Intent(this, StatusModalActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_status_modal", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 
            0, 
            intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "emoji_channel")
            .setContentTitle("🎯 Mini Emoji App")
            .setContentText("Toca para abrir modal de emojis")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(false)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        try {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
            println("✅ Notificación creada exitosamente")
        } catch (e: SecurityException) {
            println("❌ Error de permisos al crear notificación: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "emoji_channel",
                "Mini Emoji Notifications",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Notificaciones para abrir modal de emojis"
                enableLights(true)
                enableVibration(false)
                setShowBadge(true)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            println("✅ Canal de notificación creado")
        }
    }
}