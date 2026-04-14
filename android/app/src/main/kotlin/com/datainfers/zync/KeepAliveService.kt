package com.datainfers.zync

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Servicio foreground ligero para mantener el proceso vivo
 * Patrón usado por WhatsApp/Telegram para evitar process kill de Android
 */
class KeepAliveService : Service() {

    // ========================================================================
    // [CAMBIO 6] Handler periódico — re-llama startForeground() cada 5 s
    // Fecha: 2026-04-14
    //
    // PROBLEMA ORIGINAL:
    // - OEM agresivos (Samsung "Borrar todo", Xiaomi MIUI, Huawei) pueden descartar
    //   la notificación foreground después de un tiempo aunque START_STICKY esté activo.
    //   Esto hace que el ícono "i" desaparezca sin que el usuario haya reabierto la app.
    //
    // SOLUCIÓN IMPLEMENTADA:
    // - Un Handler en el main looper re-llama startForeground() cada KEEP_ALIVE_INTERVAL_MS.
    // - Re-llamar startForeground() con la misma notificación es idempotente: si ya existe,
    //   Android simplemente la reafirma; no crea duplicados ni genera vibración/sonido.
    // - El handler se cancela en onDestroy() para no leak de callbacks.
    // ========================================================================
    private val keepAliveHandler = Handler(Looper.getMainLooper())
    private val keepAliveRunnable = object : Runnable {
        override fun run() {
            try {
                val notification = createNotification()
                startForeground(NOTIFICATION_ID, notification)
                Log.d(TAG, "🔄 [KEEP-ALIVE] startForeground re-afirmado (handler periódico)")
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ [KEEP-ALIVE] Error en tick periódico: ${e.message}")
            }
            keepAliveHandler.postDelayed(this, KEEP_ALIVE_INTERVAL_MS)
        }
    }

    companion object {
        private const val TAG = "KeepAliveService"
        // Canal propio del Modo Silencio — IMPORTANCE_HIGH evita que Samsung lo descarte
        // con "Borrar todo". Canal nuevo (_v2) para forzar recreación con la nueva importance.
        private const val CHANNEL_ID = "zync_silent_mode_v2"
        private const val NOTIFICATION_ID = 12346
        // Cambio 6: Intervalo del handler periódico que re-llama startForeground().
        // 5 s es suficientemente frecuente para resistir OEM agresivos (Samsung, Xiaomi)
        // sin impacto perceptible en batería (la notificación ya existe; solo se reafirma).
        private const val KEEP_ALIVE_INTERVAL_MS = 5_000L
        
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

        // Cambio 6: Iniciar handler periódico. Cancelar cualquier callback previo primero
        // para evitar duplicados si onStartCommand se llama más de una vez (START_STICKY restart).
        keepAliveHandler.removeCallbacks(keepAliveRunnable)
        keepAliveHandler.postDelayed(keepAliveRunnable, KEEP_ALIVE_INTERVAL_MS)
        Log.d(TAG, "🔄 [KEEP-ALIVE] Handler periódico iniciado (intervalo: ${KEEP_ALIVE_INTERVAL_MS}ms)")

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

        // Cambio 6: Cancelar handler periódico para evitar callbacks tras destrucción.
        keepAliveHandler.removeCallbacks(keepAliveRunnable)
        Log.d(TAG, "🔄 [KEEP-ALIVE] Handler periódico cancelado en onDestroy()")

        // Point 3.1: Si el servicio se destruye inesperadamente (no por logout manual),
        // Android lo reiniciará automáticamente gracias a START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Modo Silencio",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Activo mientras el Modo Silencio está encendido"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Canal de notificación creado")
        }
    }
    
    private fun createNotification(): Notification {
        // Tap en notificación → abre EmojiDialogActivity directamente via getActivity().
        // FLAG_ACTIVITY_NEW_TASK: requerido al lanzar Activity desde Service.
        // FLAG_ACTIVITY_CLEAR_TOP: evita instancias duplicadas del modal.
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
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true) // No se puede deslizar para cerrar
            .setShowWhen(false)
            .build()
    }
}
