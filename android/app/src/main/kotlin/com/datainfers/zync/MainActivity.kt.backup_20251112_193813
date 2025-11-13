package com.datainfers.zync

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "mini_emoji/notification"
    private val KEEP_ALIVE_CHANNEL = "zync/keep_alive"
    private val NATIVE_STATE_CHANNEL = "zync/native_state"
    private val NOTIFICATION_ID = 12345
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 100
    private val TAG = "MainActivity"
    
    // Keep-alive state
    private var isKeepAliveRunning = false
    
    // Current user (sincronizado con Flutter)
    private var currentUserId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // � FASE 1: Inicializar cache nativo ANTES de Flutter
        val cacheStart = System.currentTimeMillis()
        NativeStateManager.initCache(this)
        val cacheDuration = System.currentTimeMillis() - cacheStart
        
        // Verificar si hay estado guardado
        currentUserId = NativeStateManager.getUserId(this)
        
        // �📊 PERFORMANCE: Detectar si es recreación o primer launch
        val wasRunning = savedInstanceState?.getBoolean("was_running", false) ?: false
        if (wasRunning) {
            Log.d(TAG, "onCreate() - Restaurando estado (Android destruyó la actividad)")
            Log.d(TAG, "⚡ Cache nativo: ${cacheDuration}ms | userId: $currentUserId")
        } else {
            Log.d(TAG, "onCreate() - Primer lanzamiento")
            Log.d(TAG, "⚡ Cache nativo: ${cacheDuration}ms | userId: $currentUserId")
        }
        
        // Debug: Mostrar info completa
        if (currentUserId != null) {
            Log.d(TAG, NativeStateManager.getDebugInfo(this))
        }
    }
    
    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        // Guardar flag para saber que no es primer launch
        outState.putBoolean("was_running", true)
        Log.d(TAG, "onSaveInstanceState() - Estado guardado")
    }
    
    override fun onRestoreInstanceState(savedInstanceState: Bundle) {
        super.onRestoreInstanceState(savedInstanceState)
        Log.d(TAG, "onRestoreInstanceState() - Estado restaurado")
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause() - App minimizada/pausada")
        
        // 🚀 FASE 1: Iniciar keep-alive NATIVO (no esperar a Flutter)
        if (!isKeepAliveRunning) {
            Log.d(TAG, "🟢 [NATIVO] Iniciando keep-alive service desde onPause()")
            KeepAliveService.start(this)
            isKeepAliveRunning = true
        }
        
        // 🚀 FASE 1: Guardar estado NATIVO inmediatamente
        currentUserId?.let { userId ->
            Log.d(TAG, "💾 [NATIVO] Guardando estado: $userId")
            NativeStateManager.saveUserState(this, userId)
        }
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume() - App maximizada/resumida")
        
        // 🚀 FASE 1: Detener keep-alive al resumir
        if (isKeepAliveRunning) {
            Log.d(TAG, "🔴 [NATIVO] Deteniendo keep-alive service desde onResume()")
            KeepAliveService.stop(this)
            isKeepAliveRunning = false
        }
    }
    
    override fun onStop() {
        super.onStop()
        Log.d(TAG, "onStop() - Activity detenida (no visible)")
    }
    
    override fun onRestart() {
        super.onRestart()
        Log.d(TAG, "onRestart() - Activity reiniciada desde onStop()")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy() - Activity destruida")
        
        // Point 21 FASE 1: SIEMPRE mantener keep-alive activo
        // El logout manual se manejará desde Flutter (Settings)
        if (!isKeepAliveRunning) {
            Log.d(TAG, "⚠️ [NATIVO] Keep-alive no estaba corriendo - iniciando desde onDestroy()")
            KeepAliveService.start(this)
            isKeepAliveRunning = true
        }
    }
    
    // 🚀 FASE 1.5: Interceptar back gesture para MINIMIZAR en vez de CERRAR
    // Esto previene que Android mate el proceso, manteniendo la app instantánea
    override fun onBackPressed() {
        Log.d(TAG, "🔙 [UX] Back gesture interceptado - minimizando en vez de cerrar")
        
        // Minimizar app al background (como presionar HOME)
        // Esto llama a onPause() donde keep-alive se activa
        moveTaskToBack(true)
        
        // NO llamar super.onBackPressed() porque eso cierra la app
        // super.onBackPressed()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d(TAG, "Nueva intent recibida")
        
        if (intent.getBooleanExtra("open_emoji_modal", false)) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                val channel = MethodChannel(messenger, CHANNEL)
                channel.invokeMethod("showEmojiModal", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Point 21 FASE 5: Handler para abrir StatusModalActivity desde Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.datainfers.zync/status_modal").setMethodCallHandler { call, result ->
            when (call.method) {
                "openModal" -> {
                    Log.d(TAG, "[FASE 5] Abriendo StatusModalActivity desde Flutter...")
                    try {
                        val intent = Intent(this, StatusModalActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        startActivity(intent)
                        result.success(true)
                        Log.d(TAG, "[FASE 5] StatusModalActivity iniciada exitosamente")
                    } catch (e: Exception) {
                        Log.e(TAG, "[FASE 5] Error abriendo StatusModalActivity: ${e.message}")
                        result.error("OPEN_MODAL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // 🚀 FASE 1: Canal para Native State (Flutter ↔ Kotlin)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_STATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setUserId" -> {
                    val userId = call.argument<String>("userId")
                    val email = call.argument<String>("email") ?: ""
                    val circleId = call.argument<String>("circleId") ?: ""
                    
                    if (userId != null && userId.isNotEmpty()) {
                        Log.d(TAG, "📤 [FLUTTER→KOTLIN] Sincronizando userId: $userId")
                        currentUserId = userId
                        NativeStateManager.saveUserState(this, userId, email, circleId)
                        result.success(true)
                    } else {
                        // Logout - limpiar estado
                        Log.d(TAG, "🧹 [FLUTTER→KOTLIN] Limpiando estado (logout)")
                        currentUserId = null
                        NativeStateManager.clear(this)
                        result.success(true)
                    }
                }
                "getUserId" -> {
                    val userId = NativeStateManager.getUserId(this)
                    Log.d(TAG, "📥 [KOTLIN→FLUTTER] Enviando userId: $userId")
                    result.success(userId)
                }
                "getDebugInfo" -> {
                    val info = NativeStateManager.getDebugInfo(this)
                    Log.d(TAG, "🔍 [KOTLIN→FLUTTER] Debug info solicitado")
                    result.success(info)
                }
                else -> result.notImplemented()
            }
        }
        
        // Canal para keep-alive service (mantener por compatibilidad)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEEP_ALIVE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    Log.d(TAG, "🟢 Flutter solicita iniciar keep-alive service")
                    KeepAliveService.start(this)
                    isKeepAliveRunning = true
                    result.success(true)
                }
                "stop" -> {
                    Log.d(TAG, "🔴 Flutter solicita detener keep-alive service (LOGOUT MANUAL)")
                    KeepAliveService.stop(this)
                    isKeepAliveRunning = false
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Point 21 FASE 5: Canal para notificaciones (apunta a StatusModalActivity)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success("Permisos solicitados")
                }
                "showNotification" -> {
                    Log.d(TAG, "[FASE 5] Creando notificación nativa persistente")
                    if (hasNotificationPermission()) {
                        showPersistentNotification()
                        result.success("✅ Notificación mostrada - tap abre StatusModalActivity")
                    } else {
                        result.error("NO_PERMISSION", "Permisos de notificación requeridos", null)
                    }
                }
                "openNotificationSettings" -> {
                    Log.d(TAG, "[FASE 5] 🔧 Abriendo Settings de notificaciones...")
                    try {
                        val intent = Intent().apply {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                action = android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                action = android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                data = android.net.Uri.parse("package:$packageName")
                            }
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                        Log.d(TAG, "[FASE 5] ✅ Settings abierto exitosamente")
                    } catch (e: Exception) {
                        Log.e(TAG, "[FASE 5] ❌ Error abriendo Settings: ${e.message}")
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
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
                    showPersistentNotification()
                } else {
                    Log.w(TAG, "Permisos de notificación denegados")
                }
            }
        }
    }

    private fun showPersistentNotification() {
        createNotificationChannel()
        
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
            Log.d(TAG, "Notificación creada exitosamente")
        } catch (e: SecurityException) {
            Log.e(TAG, "Error de permisos al crear notificación: ${e.message}")
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
        }
    }
}

/////////////////////////////////////////

// package com.datainfers.zync

// import android.Manifest
// import android.app.NotificationChannel
// import android.app.NotificationManager
// import android.app.PendingIntent
// import android.content.Context
// import android.content.Intent
// import android.content.pm.PackageManager
// import android.os.Build
// import androidx.core.app.ActivityCompat
// import androidx.core.app.NotificationCompat
// import androidx.core.app.NotificationManagerCompat
// import androidx.core.content.ContextCompat
// import io.flutter.embedding.android.FlutterActivity
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.MethodChannel

// class MainActivity: FlutterActivity() {
//     private val CHANNEL = "mini_emoji/notification"
//     private val KEEP_ALIVE_CHANNEL = "zync/keep_alive"
//     private val NOTIFICATION_ID = 12345
//     private val NOTIFICATION_PERMISSION_REQUEST_CODE = 100

//     override fun onCreate(savedInstanceState: android.os.Bundle?) {
//         super.onCreate(savedInstanceState)
        
//         // 🚀 KEEP ALIVE: Iniciar servicio foreground permanente
//         // Esto previene que Android destruya la actividad
//         KeepAliveService.start(this)
//     }

//     override fun onDestroy() {
//         // Solo detener servicio si la app se cierra completamente
//         // NO cuando minimiza (por eso no detenemos aquí)
//         super.onDestroy()
//     }

//     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//         super.configureFlutterEngine(flutterEngine)
        
//         // Canal de notificaciones
//         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "requestNotificationPermission" -> {
//                     requestNotificationPermission()
//                     result.success("Permisos solicitados")
//                 }
//                 "showNotification" -> {
//                     if (hasNotificationPermission()) {
//                         showPersistentNotification()
//                         result.success("Notificación mostrada")
//                     } else {
//                         result.error("NO_PERMISSION", "Permisos de notificación requeridos", null)
//                     }
//                 }
//                 else -> result.notImplemented()
//             }
//         }
        
//         // Canal de Keep Alive Service
//         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEEP_ALIVE_CHANNEL).setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "stopKeepAlive" -> {
//                     KeepAliveService.stop(this)
//                     result.success("Servicio detenido")
//                 }
//                 else -> result.notImplemented()
//             }
//         }
//     }
    
//     override fun onNewIntent(intent: Intent) {
//         super.onNewIntent(intent)
//         setIntent(intent)
//         if (intent.getBooleanExtra("open_emoji_modal", false)) {
//             // Enviar a Flutter para abrir modal
//             flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
//                 val channel = MethodChannel(messenger, CHANNEL)
//                 channel.invokeMethod("showEmojiModal", null)
//             }
//         }
//     }

//     private fun hasNotificationPermission(): Boolean {
//         return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
//             ContextCompat.checkSelfPermission(
//                 this,
//                 Manifest.permission.POST_NOTIFICATIONS
//             ) == PackageManager.PERMISSION_GRANTED
//         } else {
//             // En versiones anteriores a Android 13, los permisos se otorgan automáticamente
//             true
//         }
//     }

//     private fun requestNotificationPermission() {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
//             if (!hasNotificationPermission()) {
//                 ActivityCompat.requestPermissions(
//                     this,
//                     arrayOf(Manifest.permission.POST_NOTIFICATIONS),
//                     NOTIFICATION_PERMISSION_REQUEST_CODE
//                 )
//             }
//         }
//     }

//     override fun onRequestPermissionsResult(
//         requestCode: Int,
//         permissions: Array<out String>,
//         grantResults: IntArray
//     ) {
//         super.onRequestPermissionsResult(requestCode, permissions, grantResults)
//         when (requestCode) {
//             NOTIFICATION_PERMISSION_REQUEST_CODE -> {
//                 if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
//                     // Permisos otorgados, podemos mostrar notificaciones
//                     showPersistentNotification()
//                 } else {
//                     // Permisos denegados
//                     println("❌ Permisos de notificación denegados")
//                 }
//             }
//         }
//     }

//     private fun showPersistentNotification() {
//         createNotificationChannel()
        
//         // Point 15: Usar StatusModalActivity en lugar de MainActivity
//         // Esto evita abrir la app completa, solo el modal transparente
//         val intent = Intent(this, StatusModalActivity::class.java).apply {
//             flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
//             putExtra("open_status_modal", true)
//         }
        
//         val pendingIntent = PendingIntent.getActivity(
//             this, 
//             0, 
//             intent, 
//             PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//         )

//         val notification = NotificationCompat.Builder(this, "emoji_channel")
//             .setContentTitle("🎯 Mini Emoji App")
//             .setContentText("Toca para abrir modal de emojis")
//             .setSmallIcon(android.R.drawable.ic_dialog_info)
//             .setPriority(NotificationCompat.PRIORITY_DEFAULT)
//             .setContentIntent(pendingIntent)
//             .setAutoCancel(false)
//             .setOngoing(true)
//             .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
//             .build()

//         try {
//             NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
//             println("✅ Notificación creada exitosamente")
//         } catch (e: SecurityException) {
//             println("❌ Error de permisos al crear notificación: ${e.message}")
//         }
//     }

//     private fun createNotificationChannel() {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//             val channel = NotificationChannel(
//                 "emoji_channel",
//                 "Mini Emoji Notifications",
//                 NotificationManager.IMPORTANCE_DEFAULT
//             ).apply {
//                 description = "Notificaciones para abrir modal de emojis"
//                 enableLights(true)
//                 enableVibration(false)
//                 setShowBadge(true)
//             }
//             val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//             notificationManager.createNotificationChannel(channel)
//             println("✅ Canal de notificación creado")
//         }
//     }
// }