package com.datainfers.zync

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * Activity transparente que procesa QuickActions sin mostrar UI.
 * 
 * Esta activity se lanza cuando el usuario toca un shortcut de estado,
 * procesa la acción silenciosamente y se cierra inmediatamente.
 */
class QuickActionActivity : Activity() {
    companion object {
        private const val TAG = "QuickActionActivity"
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "════════════════════════════════════════════════════════")
        Log.d(TAG, "🚀 QuickActionActivity iniciada")
        Log.d(TAG, "════════════════════════════════════════════════════════")
        
        val shortcutType = intent.getStringExtra("shortcut_type")
        
        if (shortcutType != null) {
            Log.d(TAG, "📝 Procesando shortcut: $shortcutType")
            
            when (shortcutType) {
                "logout" -> {
                    // Redirigir a MainActivity para logout
                    Log.d(TAG, "🚪 Logout - Redirigiendo a MainActivity")
                    val mainIntent = Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("quick_action_logout", true)
                    }
                    startActivity(mainIntent)
                }
                
                else -> {
                    // Guardar estado en cache
                    Log.d(TAG, "💾 Estado: $shortcutType - Guardando en cache")
                    
                    val prefs = getSharedPreferences("pending_status", MODE_PRIVATE)
                    prefs.edit().apply {
                        putString("statusType", shortcutType)
                        putLong("timestamp", System.currentTimeMillis())
                        apply()
                    }
                    
                    Log.d(TAG, "✅ Estado guardado en cache")
                    
                    // CRÍTICO: Si la app está corriendo (minimizada), enviar broadcast
                    if (isAppRunning()) {
                        Log.d(TAG, "🔔 App está corriendo - Enviando broadcast")
                        val broadcastIntent = Intent("com.datainfers.zync.UPDATE_STATUS").apply {
                            putExtra("statusType", shortcutType)
                        }
                        sendBroadcast(broadcastIntent)
                        Log.d(TAG, "✅ Broadcast enviado")
                    } else {
                        Log.d(TAG, "💤 App NO está corriendo - Estado se procesará al abrir")
                    }
                }
            }
        } else {
            Log.w(TAG, "⚠️ shortcut_type es null")
        }
        
        // Cerrar inmediatamente
        finish()
    }
    
    /**
     * Verifica si la app principal está corriendo (aunque esté en background)
     */
    private fun isAppRunning(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val runningApps = activityManager.runningAppProcesses ?: return false
        
        val packageName = applicationContext.packageName
        return runningApps.any { 
            it.processName == packageName && 
            it.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE
        }
    }
}
