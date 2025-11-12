package com.datainfers.zync

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Point 21 FASE 5: Actividad transparente que abre solo el modal de estados
 * NO abre la app principal, solo muestra el overlay de emojis
 */
class StatusModalActivity : FlutterActivity() {
    private val CHANNEL = "com.datainfers.zync/status_modal"
    private val TAG = "StatusModalActivity"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d(TAG, "[FASE 5] onCreate - abriendo modal transparente")
        super.onCreate(savedInstanceState)
        
        // Configurar como overlay transparente
        window.setFlags(
            android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        )
        
        window.setFlags(
            android.view.WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            android.view.WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
        )
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "[FASE 5] Configurando Flutter engine para modal")
        
        // Configurar canal de comunicación con Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openStatusModal" -> {
                    Log.d(TAG, "[FASE 5] Solicitud de abrir modal recibida")
                    result.success(true)
                }
                "closeModal" -> {
                    Log.d(TAG, "[FASE 5] Cerrando modal - finalizando activity")
                    finish()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Point 21 FASE 5: Auto-abrir el modal al crear la activity
        // Esperamos un frame para que Flutter esté listo
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            Log.d(TAG, "[FASE 5] Invocando openStatusModal en Flutter...")
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("openStatusModal", null, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.d(TAG, "[FASE 5] ✅ Modal abierto exitosamente")
                    }
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e(TAG, "[FASE 5] ❌ Error abriendo modal: $errorMessage")
                    }
                    override fun notImplemented() {
                        Log.e(TAG, "[FASE 5] ❌ openStatusModal no implementado en Flutter")
                    }
                })
        }, 100) // 100ms de delay para asegurar que Flutter esté listo
    }
    
    override fun onBackPressed() {
        Log.d(TAG, "[FASE 5] Back pressed - cerrando modal")
        finish()
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "[FASE 5] onPause - cerrando modal para comportamiento silencioso")
        // Cerrar cuando se minimiza para mantener comportamiento silencioso
        finish()
    }
    
    override fun onDestroy() {
        Log.d(TAG, "[FASE 5] onDestroy - modal cerrado")
        super.onDestroy()
    }
}