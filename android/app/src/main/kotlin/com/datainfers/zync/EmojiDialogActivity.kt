package com.datainfers.zync

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * Modal nativo de Android para selección de emojis
 * NO inicia Flutter - apertura instantánea (<100ms)
 */
class EmojiDialogActivity : Activity() {
    private val TAG = "EmojiDialogActivity"
    
    // Grid 4x4 exactamente como Flutter (StatusType enum)
    // Emoji + Label para coincidir con diseño Flutter
    private val emojis = listOf(
        // Fila 1: Estados de disponibilidad básica
        Triple("🟢", "Libre", "available"),
        Triple("🔴", "Ocupado", "busy"),
        Triple("🟡", "Ausente", "away"),
        Triple("🎯", "Concentr", "focus"),
        // Fila 2: Estados emocionales/físicos
        Triple("😊", "Feliz", "happy"),
        Triple("😴", "Cansado", "tired"),
        Triple("😰", "Estrés", "stressed"),
        Triple("😢", "Triste", "sad"),
        // Fila 3: Estados de actividad/ubicación
        Triple("✈️", "Viajando", "traveling"),
        Triple("👥", "Reunión", "meeting"),
        Triple("📚", "Estudia", "studying"),
        Triple("🍽️", "Comiendo", "eating"),
        // Fila 4: Solo SOS (posición 15, resto vacío)
        Triple("", "", ""),
        Triple("", "", ""),
        Triple("", "", ""),
        Triple("🆘", "SOS", "sos")
    )
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "⚡ [NATIVE] Abriendo dialog nativo de emojis...")
        
        // Mostrar dialog inmediatamente
        showEmojiDialog()
    }
    
    private fun showEmojiDialog() {
        // Crear GridLayout para los emojis
        val gridLayout = GridLayout(this).apply {
            columnCount = 4
            rowCount = 4
            setPadding(40, 40, 40, 40)
        }
        
        // Agregar cada emoji al grid con estilo Flutter
        emojis.forEach { (emoji, label, statusType) ->
            if (emoji.isEmpty()) {
                // Espacio vacío
                gridLayout.addView(LinearLayout(this))
                return@forEach
            }
            
            // Contenedor vertical: emoji arriba, texto abajo
            val container = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(12, 12, 12, 12)
                
                // Fondo gris redondeado (EXACTO como Flutter)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#2C2C2C")) // Gris oscuro (igual a Flutter)
                    cornerRadius = 16f * resources.displayMetrics.density // 16dp (igual a Flutter)
                }
                
                // Ripple effect para feedback visual
                foreground = android.graphics.drawable.RippleDrawable(
                    android.content.res.ColorStateList.valueOf(Color.parseColor("#1CE4B3")),
                    null,
                    GradientDrawable().apply {
                        setColor(Color.WHITE)
                        cornerRadius = 16f * resources.displayMetrics.density
                    }
                )
                
                // Tamaño del botón
                val size = 180 // dp
                layoutParams = GridLayout.LayoutParams().apply {
                    width = size
                    height = size
                    setMargins(12, 12, 12, 12)
                }
            }
            
            // Emoji (arriba) - EXACTO como Flutter: 32sp
            val emojiView = TextView(this).apply {
                text = emoji
                textSize = 32f // Igual a Flutter
                gravity = Gravity.CENTER
            }
            
            // Label (abajo) - EXACTO como Flutter: 11sp
            val labelView = TextView(this).apply {
                text = label
                textSize = 11f // Igual a Flutter
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#B0B0B0")) // Gris claro (igual a Flutter)
                setPadding(0, 8, 0, 0)
            }
            
            container.addView(emojiView)
            container.addView(labelView)
            
            // Click listener con feedback visual
            container.setOnClickListener {
                Log.d(TAG, "👆 [NATIVE] Estado seleccionado: $emoji $label ($statusType)")
                
                // ✨ FEEDBACK VISUAL: Highlight temporal antes de cerrar
                container.background = GradientDrawable().apply {
                    setColor(Color.parseColor("#1CE4B3")) // Verde accent
                    cornerRadius = 16f * resources.displayMetrics.density
                }
                
                // Esperar 200ms para que el usuario vea el feedback
                container.postDelayed({
                    updateUserStatus(emoji, statusType)
                }, 200)
            }
            
            gridLayout.addView(container)
        }
        
        // Crear y mostrar dialog (sin título para coincidir con Flutter)
        val dialog = AlertDialog.Builder(this)
            .setView(gridLayout)
            .setOnCancelListener {
                Log.d(TAG, "❌ [NATIVE] Dialog cancelado")
                finish()
            }
            .create()
        
        dialog.show()
    }
    
    private fun updateUserStatus(emoji: String, status: String) {
        Log.d(TAG, "🔥 [HYBRID] Actualizando estado: $emoji ($status)")
        
        val timestamp = System.currentTimeMillis()
        
        // 🚀 PASO 1: Broadcast inmediato (si app está viva, actualiza instantáneamente)
        Log.d(TAG, "📡 [HYBRID] Paso 1/3 - Enviando broadcast inmediato")
        val intent = Intent("com.datainfers.zync.UPDATE_STATUS").apply {
            putExtra("emoji", emoji)
            putExtra("status", status)
            setPackage(packageName)
        }
        sendBroadcast(intent)
        
        // 💾 PASO 2: Guardar en cache (backup por si app está cerrada)
        Log.d(TAG, "💾 [HYBRID] Paso 2/3 - Guardando en cache")
        val prefs = getSharedPreferences("pending_status", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("statusType", status)
            .putString("emoji", emoji)
            .putLong("timestamp", timestamp)
            .apply()
        
        // 💼 PASO 3: Programar WorkManager como backup (verifica en 30s)
        Log.d(TAG, "💼 [HYBRID] Paso 3/3 - Programando WorkManager backup")
        val workData = Data.Builder()
            .putString("statusType", status)
            .putString("emoji", emoji)
            .putLong("timestamp", timestamp)
            .build()
        
        val workRequest = OneTimeWorkRequestBuilder<StatusUpdateWorker>()
            .setInitialDelay(30, TimeUnit.SECONDS)
            .setInputData(workData)
            .addTag("status_update_$timestamp")
            .build()
        
        WorkManager.getInstance(this).enqueue(workRequest)
        
        Log.d(TAG, "✅ [HYBRID] 3 pasos completados - cerrando dialog")
        finish()
    }
}