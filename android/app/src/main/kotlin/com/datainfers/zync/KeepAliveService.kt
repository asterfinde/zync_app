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
        // Usar el mismo canal e ID que la notificación persistente de MainActivity
        // para que SOLO exista una notificación visible
        private const val CHANNEL_ID = "emoji_channel"
        private const val NOTIFICATION_ID = 12345
        
        fun start(context: Context) {
            Log.d(TAG, "🟢 Iniciando servicio keep-alive")
            try {
                val intent = Intent(context, KeepAliveService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                Log.d(TAG, "✅ Servicio keep-alive iniciado exitosamente")
            } catch (e: IllegalStateException) {
                // Android 12+ (API 31+): No se puede iniciar foreground service desde background
                Log.w(TAG, "⚠️ No se pudo iniciar servicio (Android 12+ restricción): ${e.message}")
            } catch (e: Exception) {
                // Cualquier otra excepción
                Log.e(TAG, "❌ Error iniciando servicio: ${e.message}", e)
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
        
        // Point 3.1: START_STICKY garantiza que Android reinicie el servicio si lo mata
        // Esto mantiene la notificación persistente incluso si el sistema necesita memoria
        return START_STICKY
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "⚠️ onTaskRemoved() - Usuario cerró app desde recientes")
        
        // Point 3.1: Reiniciar el servicio para mantener la notificación activa
        // Esto garantiza que la notificación persista incluso cuando la app está cerrada
        val restartServiceIntent = Intent(applicationContext, KeepAliveService::class.java)
        applicationContext.startService(restartServiceIntent)
        
        Log.d(TAG, "✅ Servicio programado para reinicio automático")
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy() - Servicio destruido")
        
        // Point 3.1: Si el servicio se destruye inesperadamente (no por logout manual),
        // Android lo reiniciará automáticamente gracias a START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Zync en segundo plano",
                NotificationManager.IMPORTANCE_DEFAULT
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
        // ✅ Abrir EmojiDialogActivity (nativo INSTANTÁNEO con cache Firebase)
        val intent = Intent(this, EmojiDialogActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Zync")
            .setContentText("Toca para cambiar tu estado") // Point 21: Texto claro
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Usar icono genérico por ahora
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(true) // No se puede deslizar para cerrar
            .setShowWhen(false)
            .build()
    }
}
