// android/app/src/main/kotlin/com/datainfers/zync/QuickActionReceiver.kt

package com.datainfers.zync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receiver para manejar QuickActions (App Shortcuts) sin abrir la app.
 * 
 * Comportamiento:
 * - "logout": Abre MainActivity normalmente
 * - Otros estados: Guarda en cache nativo SIN abrir la app
 */
class QuickActionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "QuickActionReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val shortcutType = intent.getStringExtra("shortcut_type")
        
        Log.d(TAG, "════════════════════════════════════════════════════════")
        Log.d(TAG, "🚀 QuickAction recibido: $shortcutType")
        Log.d(TAG, "════════════════════════════════════════════════════════")
        
        if (shortcutType == null) {
            Log.w(TAG, "⚠️ shortcut_type es null, ignorando")
            return
        }
        
        when (shortcutType) {
            "logout" -> {
                // Caso especial: Cerrar Sesión - ABRIR la app normalmente
                Log.d(TAG, "🚪 Logout detectado - Abriendo MainActivity...")
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("quick_action_logout", true)
                }
                context.startActivity(launchIntent)
                Log.d(TAG, "✅ MainActivity lanzada para logout")
            }
            
            else -> {
                // Caso normal: Actualización de estado - NO ABRIR la app
                Log.d(TAG, "📝 Estado detectado: $shortcutType - Guardando en cache...")
                
                // Guardar en SharedPreferences para procesamiento posterior
                val prefs = context.getSharedPreferences("pending_status", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putString("statusType", shortcutType)
                    putLong("timestamp", System.currentTimeMillis())
                    apply()
                }
                
                Log.d(TAG, "✅ Estado guardado en cache - NO se abrirá la app")
                Log.d(TAG, "ℹ️ Se actualizará en Firebase cuando el usuario abra la app naturalmente")
            }
        }
    }
}
