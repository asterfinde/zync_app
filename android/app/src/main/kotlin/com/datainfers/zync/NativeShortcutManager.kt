package com.datainfers.zync

import android.content.Context
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * Servicio nativo para gestionar App Shortcuts (QuickActions) sin usar Flutter.
 * 
 * Los shortcuts apuntan a QuickActionActivity (transparente),
 * permitiendo actualizaciones silenciosas sin abrir la app.
 */
object NativeShortcutManager {
    private const val TAG = "NativeShortcutManager"
    
    /**
     * Configura shortcuts basados en membresía del círculo.
     * 
     * @param context Contexto de la aplicación
     * @param hasCircle Si el usuario pertenece a un círculo
     * @param shortcuts Lista de shortcuts a configurar (máximo 4)
     */
    @RequiresApi(Build.VERSION_CODES.N_MR1)
    fun updateShortcuts(
        context: Context,
        hasCircle: Boolean,
        shortcuts: List<ShortcutData> = emptyList()
    ) {
        val shortcutManager = context.getSystemService(ShortcutManager::class.java)
        
        if (shortcutManager == null) {
            Log.w(TAG, "⚠️ ShortcutManager no disponible")
            return
        }
        
        // LÓGICA CORREGIDA: hasCircle=true → 4 estados, hasCircle=false → solo logout
        val shortcutList = if (hasCircle) {
            // Usuario CON círculo: 4 estados
            Log.d(TAG, "👥 Usuario con círculo - Configurando ${shortcuts.size} estados")
            shortcuts.take(4).map { createStatusShortcut(context, it) }
        } else {
            // Usuario SIN círculo: Solo "Cerrar Sesión"
            Log.d(TAG, "👤 Usuario sin círculo - Configurando solo Logout")
            listOf(createLogoutShortcut(context))
        }
        
        try {
            shortcutManager.dynamicShortcuts = shortcutList
            Log.d(TAG, "✅ Shortcuts actualizados: ${shortcutList.size} items")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error actualizando shortcuts: ${e.message}")
        }
    }
    
    /**
     * Crea shortcut para cerrar sesión (abre MainActivity)
     */
    @RequiresApi(Build.VERSION_CODES.N_MR1)
    private fun createLogoutShortcut(context: Context): ShortcutInfo {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("quick_action_logout", true)
        }
        
        return ShortcutInfo.Builder(context, "logout")
            .setShortLabel("Cerrar Sesión")
            .setLongLabel("🚪 Cerrar Sesión")
            .setIcon(Icon.createWithResource(context, android.R.drawable.ic_lock_power_off))
            .setIntent(intent)
            .build()
    }
    
    /**
     * Crea shortcut para actualizar estado (NO abre la app)
     * SIN ícono para evitar círculos blancos
     */
    @RequiresApi(Build.VERSION_CODES.N_MR1)
    private fun createStatusShortcut(context: Context, data: ShortcutData): ShortcutInfo {
        // Intent que apunta a QuickActionActivity (activity transparente)
        val intent = Intent(context, QuickActionActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("shortcut_type", data.type)
            // Flags para evitar que se agregue al stack de activities
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        // NO usar setIcon() para evitar círculos blancos
        // Android usará solo el texto (emoji + descripción)
        return ShortcutInfo.Builder(context, data.type)
            .setShortLabel("${data.emoji} ${data.label}") // Emoji + descripción
            .setLongLabel("${data.emoji} ${data.label}") // Mismo texto largo
            .setIntent(intent)
            .build()
    }
    
    /**
     * Limpia todos los shortcuts
     */
    @RequiresApi(Build.VERSION_CODES.N_MR1)
    fun clearShortcuts(context: Context) {
        val shortcutManager = context.getSystemService(ShortcutManager::class.java)
        shortcutManager?.removeAllDynamicShortcuts()
        Log.d(TAG, "🧹 Shortcuts limpiados")
    }
}

/**
 * Datos para crear un shortcut de estado
 */
data class ShortcutData(
    val type: String,      // "fine", "busy", "sos", etc.
    val emoji: String,     // "🟢", "🔴", "🆘", etc.
    val label: String      // "Todo bien", "Ocupado", "SOS", etc.
)
