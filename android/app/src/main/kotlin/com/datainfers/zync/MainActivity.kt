package com.datainfers.zync

import android.util.Log
import android.widget.Toast
import android.os.Bundle
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.datainfers.zync.QuickActionReceiver

class MainActivity: FlutterActivity() {
    private lateinit var methodChannel: MethodChannel
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("ZYNC", "onCreate llamado - inicializando MethodChannel...")
        
        // Manejar intent inicial si viene desde notificación
        handleQuickStatusIntent(intent)
        
        // Procesar intent inicial si viene desde notificación
        if (intent.getBooleanExtra("show_quick_modal", false)) {
            Log.d("ZYNC", "show_quick_modal detectado en onCreate")
            Toast.makeText(this, "Modal desde onCreate", Toast.LENGTH_SHORT).show()
        }
    }
    
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        val engine = super.provideFlutterEngine(context) ?: FlutterEngine(context)
        io.flutter.embedding.engine.FlutterEngineCache.getInstance().put("my_engine_id", engine)
        return engine
    }
    private val CHANNEL = "zync/notification"
    private val NOTIFICATION_ID = 12346

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d("ZYNC", "Configurando Flutter Engine y MethodChannel...")
        
        // Inicializar MethodChannel aquí donde SÍ se ejecuta
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        Log.d("ZYNC", "MethodChannel creado como propiedad de clase")
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hideCustomNotification" -> {
                    hideCustomNotification()
                    result.success(null)
                }
                "updateNotificationWithActions" -> {
                    val actions = call.argument<List<Map<String, String>>>("actions")
                    if (actions != null) {
                        updateNotificationWithActions(actions)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Solo una función onNewIntent, combinando ambas lógicas
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("ZYNC", "onNewIntent recibido")
        Toast.makeText(this, "onNewIntent recibido", Toast.LENGTH_SHORT).show()
        
        // IMPORTANTE: Establecer el nuevo intent como el intent actual
        setIntent(intent)
        
        // Debug: Imprimir todos los extras del intent
        Log.d("ZYNC", "Intent extras: " + intent.extras?.toString())
        val hasModalExtra = intent.getBooleanExtra("show_quick_modal", false)
        val hasFlutterForegroundExtra = intent.getStringExtra("intentData") == "onNotificationPressed"
        
        Log.d("ZYNC", "show_quick_modal extra value: $hasModalExtra")
        Log.d("ZYNC", "FlutterForegroundTask extra detected: $hasFlutterForegroundExtra")
        
        handleQuickStatusIntent(intent)
        
        // Tratar AMBOS casos como modal request
        if (hasModalExtra || hasFlutterForegroundExtra) {
            Log.d("ZYNC", "Modal solicitado (nativo o FlutterForegroundTask), enviando a Flutter")
            Toast.makeText(this, "Modal detectado!", Toast.LENGTH_SHORT).show()
            
            // Usar Handler para asegurar que Flutter esté listo
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                Log.d("ZYNC", "Enviando showQuickStatusModal a Flutter (con delay)")
                Log.d("ZYNC", "Verificando si methodChannel está inicializado...")
                
                try {
                    if (::methodChannel.isInitialized) {
                        Log.d("ZYNC", "MethodChannel está inicializado, enviando método...")
                        methodChannel.invokeMethod("showQuickStatusModal", null)
                        Log.d("ZYNC", "Método enviado exitosamente")
                    } else {
                        Log.e("ZYNC", "ERROR: methodChannel NO está inicializado")
                    }
                } catch (e: Exception) {
                    Log.e("ZYNC", "Error enviando a MethodChannel: $e")
                }
            }, 200) // 200ms delay
        } else {
            Log.d("ZYNC", "NO se detectó solicitud de modal")
            Toast.makeText(this, "NO solicitud de modal", Toast.LENGTH_SHORT).show()
        }
    }

    private fun handleQuickStatusIntent(intent: Intent) {
        val action = intent.getStringExtra("quick_status_action")
        if (action != null) {
            // Enviar a Flutter por MethodChannel
            val engine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("my_engine_id")
            if (engine != null) {
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onQuickStatusSelected", action)
            } else {
                // fallback si engine no está cacheado
                MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, CHANNEL)
                    .invokeMethod("onQuickStatusSelected", action)
            }
        }
    }



    private fun updateNotificationWithActions(actions: List<Map<String, String>>) {
        createNotificationChannel()
        // Intent para lanzar MainActivity con un extra especial
        val mainIntent = Intent(this, MainActivity::class.java)
        mainIntent.putExtra("show_quick_modal", true)
        mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        Log.d("ZYNC", "Intent para PendingIntent: extras=" + mainIntent.extras?.toString())
        
        // CAMBIAMOS requestCode para forzar actualización del PendingIntent
        val mainPendingIntent = PendingIntent.getActivity(
            this, System.currentTimeMillis().toInt(), mainIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, "zync_quick_status_channel")
            .setContentTitle("Zync Activo")
            .setContentText("Toca para abrir Zync y enviar estado rápido")
            .setSmallIcon(R.drawable.ic_transparent) // Asegúrate de tener este recurso
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(mainPendingIntent)
            .setAutoCancel(false)
            .setOngoing(true)

        // NO agregamos acciones de emojis - solo modal
        NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, builder.build())
        Log.d("ZYNC", "Notificación creada con requestCode dinámico")
    }

    // Utilidad para evitar notificaciones duplicadas
    private fun isNotificationActive(notificationId: Int): Boolean {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activeNotifications = notificationManager.activeNotifications
            return activeNotifications.any { it.id == notificationId }
        }
        return false
    }

    private fun hideCustomNotification() {
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "zync_quick_status_channel",
                "Zync Quick Actions",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Servicio de Zync para acciones rápidas."
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}