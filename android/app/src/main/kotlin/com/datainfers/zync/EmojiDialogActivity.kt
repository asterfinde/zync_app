package com.datainfers.zync

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * Modal nativo de Android para selección de emojis
 * Diseño EXACTO al modal Flutter (status_selector_overlay.dart)
 */
class EmojiDialogActivity : Activity() {
    private val TAG = "EmojiDialogActivity"
    
    // Grid 4x4 exactamente como Flutter (StatusType enum)
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
        // Fila 4: Config + SOS (posiciones 12, 13, 14 vacías, 15 = SOS)
        Triple("", "", ""),
        Triple("", "", ""),
        Triple("", "", ""),
        Triple("🆘", "SOS", "sos")
    )
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "⚡ [NATIVE] Abriendo dialog nativo de emojis...")
        
        setupActivityUI()
    }
    
    private fun setupActivityUI() {
        // Root container con fondo semi-transparente (85% opacity como Flutter)
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#D9000000")) // 85% opacity (0.85 * 255 = 217 = D9)
            
            // Cerrar al tocar fuera
            setOnClickListener {
                Log.d(TAG, "❌ [NATIVE] Tap outside - cerrando")
                finish()
            }
        }
        
        // Container principal con marco (EXACTO como Flutter)
        val mainContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(
                dpToPx(20), // padding: 20
                dpToPx(20),
                dpToPx(20),
                dpToPx(20)
            )
            
            // Fondo gris oscuro con borde (Colors.grey.shade900.withOpacity(0.95))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F21E1E1E")) // 95% opacity grey.shade900
                cornerRadius = dpToPx(20).toFloat() // borderRadius: 20
                setStroke(
                    dpToPx(1), // width: 1
                    Color.parseColor("#80616161") // Colors.grey.shade700.withOpacity(0.5)
                )
            }
            
            // Centrar en pantalla con margen de 32dp
            val params = FrameLayout.LayoutParams(
                dpToPx(340), // ANCHO FIJO para 4 columnas: (65*4) + (10*4) + (20*2) = 340dp
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
                setMargins(dpToPx(32), dpToPx(32), dpToPx(32), dpToPx(32))
            }
            layoutParams = params
            
            // Evitar que el tap se propague al root
            isClickable = true
        }
        
        // Crear GridLayout para los emojis
        val gridLayout = GridLayout(this).apply {
            columnCount = 4
            rowCount = 4
        }
        
        // Agregar cada emoji al grid
        emojis.forEach { (emoji, label, statusType) ->
            if (emoji.isEmpty()) {
                // Espacio vacío
                gridLayout.addView(LinearLayout(this), GridLayout.LayoutParams().apply {
                    width = dpToPx(65) // Ajustado para 4 columnas
                    height = dpToPx(65)
                    setMargins(dpToPx(5), dpToPx(5), dpToPx(5), dpToPx(5)) // spacing: 10 / 2
                })
                return@forEach
            }
            
            // Contenedor vertical: emoji arriba, texto abajo
            val container = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(dpToPx(4), dpToPx(6), dpToPx(4), dpToPx(6)) // Padding compacto
                
                // Fondo gris oscuro con borde (Colors.grey.shade800.withOpacity(0.6))
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#99424242")) // 60% opacity grey.shade800
                    cornerRadius = dpToPx(12).toFloat() // borderRadius: 12
                    setStroke(
                        dpToPx(1), // width: 1
                        Color.parseColor("#66757575") // Colors.grey.shade600.withOpacity(0.4)
                    )
                }
                
                // Ripple effect
                foreground = android.graphics.drawable.RippleDrawable(
                    android.content.res.ColorStateList.valueOf(Color.parseColor("#1CE4B3")),
                    null,
                    GradientDrawable().apply {
                        setColor(Color.WHITE)
                        cornerRadius = dpToPx(12).toFloat()
                    }
                )
                
                // Tamaño del botón COMPACTO para 4 columnas
                layoutParams = GridLayout.LayoutParams().apply {
                    width = dpToPx(65) // Reducido para 4 columnas
                    height = dpToPx(65)
                    setMargins(dpToPx(5), dpToPx(5), dpToPx(5), dpToPx(5)) // spacing: 10 / 2
                }

                
                isClickable = true
            }
            
            // Emoji (EXACTO como Flutter: 24sp)
            val emojiView = TextView(this).apply {
                text = emoji
                textSize = 24f // fontSize: 24 (EXACTO)
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
            }
            
            // Label (EXACTO como Flutter: 9sp)
            val labelView = TextView(this).apply {
                text = label
                textSize = 9f // fontSize: 9 (EXACTO)
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#CCFFFFFF")) // white.withOpacity(0.8)
                setPadding(0, dpToPx(2), 0, 0) // SizedBox(height: 2)
                maxLines = 1
                ellipsize = android.text.TextUtils.TruncateAt.END
            }
            
            container.addView(emojiView)
            container.addView(labelView)
            
            // Click listener
            container.setOnClickListener {
                Log.d(TAG, "👆 [NATIVE] Estado seleccionado: $emoji $label ($statusType)")
                
                // Feedback visual
                container.background = GradientDrawable().apply {
                    setColor(Color.parseColor("#1CE4B3")) // Verde accent
                    cornerRadius = dpToPx(12).toFloat()
                }
                
                // Esperar un poco y actualizar
                container.postDelayed({
                    updateUserStatus(emoji, statusType)
                }, 150)
            }
            
            gridLayout.addView(container)
        }
        
        mainContainer.addView(gridLayout)
        root.addView(mainContainer)
        setContentView(root)
    }
    
    private fun updateUserStatus(emoji: String, status: String) {
        Log.d(TAG, "🔥 [HYBRID] Actualizando estado: $emoji ($status)")
        
        val timestamp = System.currentTimeMillis()
        
        // 🚀 PASO 1: Broadcast inmediato
        Log.d(TAG, "📡 [HYBRID] Paso 1/3 - Enviando broadcast inmediato")
        val intent = Intent("com.datainfers.zync.UPDATE_STATUS").apply {
            putExtra("emoji", emoji)
            putExtra("status", status)
            setPackage(packageName)
        }
        sendBroadcast(intent)
        
        // 💾 PASO 2: Guardar en cache
        Log.d(TAG, "💾 [HYBRID] Paso 2/3 - Guardando en cache")
        val prefs = getSharedPreferences("pending_status", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("statusType", status)
            .putString("emoji", emoji)
            .putLong("timestamp", timestamp)
            .apply()
        
        // 💼 PASO 3: Programar WorkManager como backup
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
    
    // Helper para convertir dp a px
    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}