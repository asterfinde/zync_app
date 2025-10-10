package com.datainfers.zync

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Actividad transparente que abre solo el modal de estados
 * Point 15: No abre la app principal, solo el overlay
 */
class StatusModalActivity : FlutterActivity() {
    private val CHANNEL = "com.datainfers.zync/status_modal"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d("StatusModalActivity", "onCreate - abriendo modal transparente")
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
        
        // Configurar canal de comunicación con Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openStatusModal" -> {
                    Log.d("StatusModalActivity", "Abriendo modal de estados")
                    result.success(true)
                }
                "closeModal" -> {
                    Log.d("StatusModalActivity", "Cerrando modal - finalizando activity")
                    finish()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Auto-abrir el modal al crear la activity
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .invokeMethod("openStatusModal", null)
    }
    
    override fun onBackPressed() {
        Log.d("StatusModalActivity", "Back pressed - cerrando modal")
        finish()
    }
    
    override fun onPause() {
        super.onPause()
        // Cerrar cuando se minimiza para mantener comportamiento silencioso
        finish()
    }
}