package com.datainfers.zync

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView

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
                
                // Fondo gris redondeado (como Flutter)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#2A2A2A")) // Gris oscuro
                    cornerRadius = 24f // Bordes redondeados
                }
                
                // Tamaño del botón
                val size = 180 // dp
                layoutParams = GridLayout.LayoutParams().apply {
                    width = size
                    height = size
                    setMargins(12, 12, 12, 12)
                }
            }
            
            // Emoji (arriba)
            val emojiView = TextView(this).apply {
                text = emoji
                textSize = 36f
                gravity = Gravity.CENTER
            }
            
            // Label (abajo)
            val labelView = TextView(this).apply {
                text = label
                textSize = 14f
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
                setPadding(0, 8, 0, 0)
            }
            
            container.addView(emojiView)
            container.addView(labelView)
            
            // Click listener
            container.setOnClickListener {
                Log.d(TAG, "👆 [NATIVE] Estado seleccionado: $emoji $label ($statusType)")
                updateUserStatus(emoji, statusType)
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
        Log.d(TAG, "🔥 [NATIVE] Actualizando estado: $emoji ($status)")
        
        // Enviar broadcast a MainActivity SIN abrirla
        // Esto permite actualizar Firebase sin mostrar la app
        val intent = Intent("com.datainfers.zync.UPDATE_STATUS").apply {
            putExtra("emoji", emoji)
            putExtra("status", status)
            setPackage(packageName) // Solo para esta app
        }
        
        sendBroadcast(intent)
        
        Log.d(TAG, "✅ [NATIVE] Broadcast enviado - cerrando dialog")
        finish()
    }
}