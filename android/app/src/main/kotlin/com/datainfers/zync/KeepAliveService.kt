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
            // N1.01 fix: abortar si stop() ya fue llamado para evitar que el ícono
            // reaparezca en la ventana entre stopService() y onDestroy().
            if (isBeingStopped) {
                Log.d(TAG, "🛑 [KEEP-ALIVE] Handler abortado — isBeingStopped=true")
                return
            }
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
        // Canal _v3: IMPORTANCE_LOW para reducir footprint visual — el ícono "i" sigue
        // visible pero el card no aparece en el shade ni genera sonido/vibración.
        private const val CHANNEL_ID = "zync_silent_mode_v3"
        private const val NOTIFICATION_ID = 12346
        // Cambio 6: Intervalo del handler periódico que re-llama startForeground().
        // 5 s es suficientemente frecuente para resistir OEM agresivos (Samsung, Xiaomi)
        // sin impacto perceptible en batería (la notificación ya existe; solo se reafirma).
        private const val KEEP_ALIVE_INTERVAL_MS = 5_000L

        // ========================================================================
        // [CORRECCIÓN] N1.01 — Flag para evitar reaparición del ícono tras stop()
        // Fecha: 2026-04-15
        //
        // PROBLEMA ORIGINAL:
        // - stopService() es asíncrono: onDestroy() puede tardar ~5-8s en ejecutarse.
        // - En ese intervalo, el handler periódico disparaba startForeground() y el ícono
        //   "i" reaparecía brevemente en la BN (≥8s desde el cancelAll en Regla 1).
        //
        // SOLUCIÓN IMPLEMENTADA:
        // - isBeingStopped se pone en true en stop(), antes de stopService().
        // - keepAliveRunnable comprueba el flag al inicio y aborta si está en true.
        // - Se resetea a false en start() y en onCreate() (cubre START_STICKY restart).
        // ========================================================================
        @Volatile var isBeingStopped = false

        fun start(context: Context) {
            isBeingStopped = false  // Resetear al iniciar (cubre reactivación)
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
            isBeingStopped = true   // Señal al handler de no re-afirmar startForeground()
            Log.d(TAG, "🔴 Deteniendo servicio keep-alive (isBeingStopped=true)")
            val intent = Intent(context, KeepAliveService::class.java)
            context.stopService(intent)
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        isBeingStopped = false  // Resetear si Android reinicia el servicio (START_STICKY)
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
        // START_STICKY garantiza reinicio automático si el sistema mata el proceso.
        // El startService() manual fue eliminado — era redundante y causaba un segundo
        // onStartCommand con handler duplicado al activar Modo Silencio.
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
                NotificationManager.IMPORTANCE_LOW
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
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Modo Silencio activo")
            .setContentText("Toca para cambiar tu estado")
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }
}
