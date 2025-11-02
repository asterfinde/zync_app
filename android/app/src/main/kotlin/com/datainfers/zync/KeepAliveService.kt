package com.datainfers.zync

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Servicio foreground ligero para mantener el proceso vivo
 * Patrón usado por WhatsApp/Telegram para evitar process kill de Android
 */
class KeepAliveService : Service() {
    
    companion object {
        private const val TAG = "KeepAliveService"
        private const val CHANNEL_ID = "zync_keep_alive"
        private const val NOTIFICATION_ID = 999
        
        fun start(context: Context) {
            Log.d(TAG, "🟢 Iniciando servicio keep-alive")
            val intent = Intent(context, KeepAliveService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stop(context: Context) {
            Log.d(TAG, "🔴 Deteniendo servicio keep-alive")
            val intent = Intent(context, KeepAliveService::class.java)
            context.stopService(intent)
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate() - Servicio creado")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand() - Iniciando foreground")
        
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // START_STICKY: Android reiniciará el servicio si lo mata
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy() - Servicio destruido")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Zync en segundo plano",
                NotificationManager.IMPORTANCE_LOW // BAJA importancia = silencioso
            ).apply {
                description = "Mantiene Zync listo para usarse"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Canal de notificación creado")
        }
    }
    
    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Zync")
            .setContentText("Listo para compartir ubicación")
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Usar icono genérico por ahora
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW) // Prioridad baja = no molesta
            .setOngoing(true) // No se puede deslizar para cerrar
            .setShowWhen(false)
            .build()
    }
}
