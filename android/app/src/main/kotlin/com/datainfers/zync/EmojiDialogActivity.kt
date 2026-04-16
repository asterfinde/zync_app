package com.datainfers.zync

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

/**
 * Modal nativo de Android para selección de emojis
 * Lee emojis desde SharedPreferences (cache Firebase sincronizado por Flutter)
 * Idéntico en contenido al StatusSelectorOverlay de Flutter
 */
class EmojiDialogActivity : Activity() {
    private val TAG = "EmojiDialogActivity"

    // IDs de emojis predefinidos — deben coincidir con StatusType.fallbackPredefined en Dart
    private val predefinedIds = setOf(
        "fine", "busy", "away", "do_not_disturb",
        "home", "school", "university", "work",
        "medical", "meeting", "studying", "eating",
        "exercising", "driving", "walking", "public_transport",
        "sos"
    )

    // Fallback hardcodeado — espejo exacto de StatusType.fallbackPredefined
    private val hardcodedFallback = listOf(
        Triple("🙂", "Bien", "fine"),
        Triple("🔴", "Ocupado", "busy"),
        Triple("🟡", "Ausente", "away"),
        Triple("🔕", "No molestar", "do_not_disturb"),
        Triple("🏠", "Casa", "home"),
        Triple("🏫", "Colegio", "school"),
        Triple("🎓", "Universidad", "university"),
        Triple("🏢", "Trabajo", "work"),
        Triple("🏥", "Consulta", "medical"),
        Triple("👥", "Reunión", "meeting"),
        Triple("📚", "Estudia", "studying"),
        Triple("🍽️", "Comiendo", "eating"),
        Triple("💪", "Ejercicio", "exercising"),
        Triple("🚗", "Camino", "driving"),
        Triple("🚶", "Caminando", "walking"),
        Triple("🚌", "Transporte", "public_transport"),
        Triple("🆘", "SOS", "sos")
    )

    // Emojis cargados: fallback predefinido + custom del círculo
    private lateinit var emojis: List<Triple<String, String, String>>

    // Tipos de zona configurados (se bloquean en el grid)
    private lateinit var configuredZoneTypes: Set<String>

    // SOS press & hold
    private val sosHandler = Handler(Looper.getMainLooper())
    private var sosHoldRunnable: Runnable? = null
    private var sosButtonView: LinearLayout? = null
    private var sosLabelView: TextView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "⚡ [NATIVE] Abriendo dialog nativo de emojis...")

        // 🌙 SILENT MODE: El mutex zync_modal_open fue eliminado.
        // Con el diseño mutuamente excluyente (app abierta ↔ Silent Mode activo),
        // no puede haber dos modales simultáneos — la race condition desaparece de raíz.

        emojis = loadEmojisFromCache()
        configuredZoneTypes = loadConfiguredZoneTypes()
        setupActivityUI()

        // ========================================================================
        // [CORRECCIÓN] Modo Silencio permanece activo siempre (app abierta/minimizada)
        // Fecha: 2026-04-11 (segunda iteración)
        // 
        // Ya NO necesitamos persistir timestamps porque MainActivity.onResume() ya no
        // desactiva el Modo Silencio. El ícono permanece activo siempre hasta logout.
        // 
        // CÓDIGO ANTERIOR COMENTADO (PR #94 - timestamps):
        // val openTime = System.currentTimeMillis()
        // getSharedPreferences("zync_silent_mode", Context.MODE_PRIVATE)
        //     .edit().putLong("last_modal_open_time", openTime).apply()
        // Log.d(TAG, "🔔 [SILENT-FIX] Modal abierto — timestamp guardado: $openTime")
        //
        // CÓDIGO ORIGINAL (pre-PR #94 - flag booleano):
        // getSharedPreferences("zync_silent_mode", Context.MODE_PRIVATE)
        //     .edit().putBoolean("modal_was_open", true).apply()
        // Log.d(TAG, "🔔 [SILENT] Flag modal_was_open=true guardado")
        // ========================================================================
        
        Log.d(TAG, "🔔 [SILENT] Modal abierto — Modo Silencio permanece activo (sin necesidad de flags/timestamps)")
    }

    override fun onDestroy() {
        sosHoldRunnable?.let { sosHandler.removeCallbacks(it) }
        
        // ========================================================================
        // [CORRECCIÓN] Modo Silencio permanece activo siempre (app abierta/minimizada)
        // Fecha: 2026-04-11 (segunda iteración)
        // 
        // Ya NO necesitamos persistir timestamp de cierre porque MainActivity.onResume()
        // ya no desactiva el Modo Silencio. El ícono permanece activo siempre hasta logout.
        // 
        // CÓDIGO ANTERIOR COMENTADO (PR #94 - timestamp de cierre):
        // val closeTime = System.currentTimeMillis()
        // getSharedPreferences("zync_silent_mode", Context.MODE_PRIVATE)
        //     .edit().putLong("last_modal_close_time", closeTime).apply()
        // Log.d(TAG, "🔍 [SILENT-FIX] onDestroy — timestamp de cierre guardado: $closeTime")
        // ========================================================================
        
        Log.d(TAG, "🔍 [SILENT] onDestroy — Modo Silencio permanece activo (sin necesidad de timestamps)")
        
        super.onDestroy()
    }

    /**
     * Carga emojis para el modal.
     * Estrategia: siempre usa el fallback hardcodeado como base (idéntico al StatusSelectorOverlay
     * de Flutter) y agrega encima los emojis personalizados del círculo extraídos del cache.
     * Esto garantiza que los predefinidos siempre coincidan con la fuente de la verdad,
     * independientemente del estado de Firebase.
     */
    private fun loadEmojisFromCache(): List<Triple<String, String, String>> {
        val customEmojis = mutableListOf<Triple<String, String, String>>()

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cachedJson = prefs.getString("flutter.predefined_emojis", null)

        if (cachedJson != null) {
            try {
                Log.d(TAG, "📦 [CACHE] JSON encontrado: ${cachedJson.take(100)}...")

                val jsonTrimmed = cachedJson.trim()
                if (jsonTrimmed.startsWith("[") && jsonTrimmed.endsWith("]")) {
                    val content = jsonTrimmed.substring(1, jsonTrimmed.length - 1)

                    val objects = content.split("},")
                    for (obj in objects) {
                        var cleanObj = obj.trim()
                        if (!cleanObj.endsWith("}")) cleanObj += "}"
                        if (!cleanObj.startsWith("{")) cleanObj = "{$cleanObj"

                        var id = ""
                        var emoji = ""
                        var shortLabel = ""

                        val idMatch = Regex(""""id":"([^"]+)"""").find(cleanObj)
                        val emojiMatch = Regex(""""emoji":"([^"]+)"""").find(cleanObj)
                        val labelMatch = Regex(""""shortLabel":"([^"]+)"""").find(cleanObj)

                        if (idMatch != null) id = idMatch.groupValues[1]
                        if (emojiMatch != null) emoji = emojiMatch.groupValues[1]
                        if (labelMatch != null) shortLabel = labelMatch.groupValues[1]

                        // Solo agregar si no es predefinido (son los custom del círculo)
                        if (id.isNotEmpty() && emoji.isNotEmpty() && !predefinedIds.contains(id)) {
                            customEmojis.add(Triple(emoji, shortLabel, id))
                        }
                    }
                }

                Log.d(TAG, "✅ [CACHE] ${customEmojis.size} emoji(s) personalizado(s) encontrado(s)")
            } catch (e: Exception) {
                Log.e(TAG, "❌ [CACHE] Error parseando: ${e.message}")
            }
        } else {
            Log.d(TAG, "⚠️ [CACHE] Sin cache de emojis")
        }

        val result = hardcodedFallback + customEmojis
        Log.d(TAG, "✅ [EMOJIS] Total: ${result.size} (${hardcodedFallback.size} predefinidos + ${customEmojis.size} custom)")
        return result
    }

    /**
     * Lee los tipos de zona configurados desde SharedPreferences
     * (escritos por EmojiCacheService en Flutter)
     */
    private fun loadConfiguredZoneTypes(): Set<String> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("flutter.configured_zone_types", null)
            ?: return emptySet<String>().also {
                Log.d(TAG, "⚠️ [ZONES] Sin cache de zonas configuradas")
            }

        return try {
            val result = mutableSetOf<String>()
            val trimmed = json.trim()
            if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                val content = trimmed.substring(1, trimmed.length - 1).trim()
                if (content.isNotEmpty()) {
                    content.split(",").forEach { item ->
                        val clean = item.trim().removeSurrounding("\"")
                        if (clean.isNotEmpty()) result.add(clean)
                    }
                }
            }
            Log.d(TAG, "✅ [ZONES] Zonas configuradas: $result")
            result
        } catch (e: Exception) {
            Log.e(TAG, "❌ [ZONES] Error parseando zonas: ${e.message}")
            emptySet()
        }
    }

    private fun setupActivityUI() {
        // SOS separado del grid principal
        val mainEmojis = emojis.filter { (_, _, id) -> id != "sos" }
        val sosItem = emojis.find { (_, _, id) -> id == "sos" }

        // Tamaños dinámicos basados en pantalla — espejo del comportamiento responsive de Flutter
        val screenWidthDp = (resources.displayMetrics.widthPixels / resources.displayMetrics.density).toInt()
        val screenHeightDp = (resources.displayMetrics.heightPixels / resources.displayMetrics.density).toInt()

        // Ancho del container: igual que antes (340dp) pero limitado al ancho de pantalla con margen
        val containerWidthDp = minOf(340, screenWidthDp - 64)
        val containerPaddingDp = 12
        // Ancho real disponible para el grid dentro del container
        val gridAvailableWidthDp = containerWidthDp - containerPaddingDp * 2
        val cellMarginDp = 5
        // Celda cuadrada: (ancho disponible - márgenes de 4 columnas) / 4 columnas
        val cellSizeDp = (gridAvailableWidthDp - cellMarginDp * 2 * 4) / 4
        // Altura del ScrollView: disponible = pantalla − márgenes container (64) − padding (24) − SOS+margen (78)
        // Evita overflow en landscape donde screenHeightDp es pequeño
        val scrollViewMaxHeightDp = (screenHeightDp - 166).coerceAtLeast(80)

        Log.d(TAG, "📐 [UI] screen=${screenWidthDp}x${screenHeightDp}dp, container=${containerWidthDp}dp, cell=${cellSizeDp}dp, scrollMax=${scrollViewMaxHeightDp}dp")

        // Root container con fondo semi-transparente
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#D9000000"))
            setOnClickListener {
                Log.d(TAG, "❌ [NATIVE] Tap outside - cerrando")
                finish()
            }
        }

        // Container principal
        val mainContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(containerPaddingDp), dpToPx(containerPaddingDp), dpToPx(containerPaddingDp), dpToPx(containerPaddingDp))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F21E1E1E"))
                cornerRadius = dpToPx(20).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#80616161"))
            }
            val params = FrameLayout.LayoutParams(
                dpToPx(containerWidthDp),
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
                setMargins(dpToPx(32), dpToPx(32), dpToPx(32), dpToPx(32))
            }
            layoutParams = params
            isClickable = true
        }

        // ScrollView con altura máxima responsive — se encoge si el contenido es menor (WRAP_CONTENT + AT_MOST)
        val maxScrollPx = dpToPx(scrollViewMaxHeightDp)
        val scrollView = object : android.widget.ScrollView(this) {
            override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
                val constrainedHeight = android.view.View.MeasureSpec.makeMeasureSpec(
                    maxScrollPx, android.view.View.MeasureSpec.AT_MOST
                )
                super.onMeasure(widthMeasureSpec, constrainedHeight)
            }
        }.apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            isVerticalScrollBarEnabled = true
            scrollBarStyle = android.view.View.SCROLLBARS_OUTSIDE_OVERLAY
        }

        // Grid con emojis (sin SOS) — 4 columnas con celdas cuadradas de tamaño calculado
        val gridLayout = GridLayout(this).apply {
            columnCount = 4
            useDefaultMargins = false
        }

        mainEmojis.forEach { (emoji, label, statusId) ->
            val isBlocked = configuredZoneTypes.contains(statusId)

            val container = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(dpToPx(4), dpToPx(6), dpToPx(4), dpToPx(6))
                background = GradientDrawable().apply {
                    setColor(if (isBlocked) Color.parseColor("#4D424242") else Color.parseColor("#99424242"))
                    cornerRadius = dpToPx(12).toFloat()
                    setStroke(dpToPx(1), Color.parseColor("#66757575"))
                }
                if (!isBlocked) {
                    foreground = android.graphics.drawable.RippleDrawable(
                        android.content.res.ColorStateList.valueOf(Color.parseColor("#1CE4B3")),
                        null,
                        GradientDrawable().apply {
                            setColor(Color.WHITE)
                            cornerRadius = dpToPx(12).toFloat()
                        }
                    )
                }
                layoutParams = GridLayout.LayoutParams().apply {
                    width = dpToPx(cellSizeDp)
                    height = dpToPx(cellSizeDp)
                    setMargins(dpToPx(cellMarginDp), dpToPx(cellMarginDp), dpToPx(cellMarginDp), dpToPx(cellMarginDp))
                }
                isClickable = true
                alpha = if (isBlocked) 0.35f else 1.0f
            }

            val emojiView = TextView(this).apply {
                text = emoji
                textSize = 24f
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
            }

            val labelView = TextView(this).apply {
                text = label
                textSize = 9f
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#CCFFFFFF"))
                setPadding(0, dpToPx(2), 0, 0)
                maxLines = 1
                ellipsize = android.text.TextUtils.TruncateAt.END
            }

            container.addView(emojiView)
            container.addView(labelView)

            if (isBlocked) {
                container.setOnClickListener {
                    showZoneNotAllowedDialog()
                }
            } else {
                container.setOnClickListener {
                    container.background = GradientDrawable().apply {
                        setColor(Color.parseColor("#1CE4B3"))
                        cornerRadius = dpToPx(12).toFloat()
                    }
                    container.postDelayed({ updateUserStatus(emoji, statusId) }, 150)
                }
            }

            gridLayout.addView(container)
        }

        scrollView.addView(gridLayout)
        mainContainer.addView(scrollView)

        // Botón SOS especial al fondo
        if (sosItem != null) {
            mainContainer.addView(buildSosButton(sosItem))
        }

        root.addView(mainContainer)
        setContentView(root)
    }

    private fun buildSosButton(sosItem: Triple<String, String, String>): LinearLayout {
        val (sosEmoji, _, sosId) = sosItem

        val button = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(16), dpToPx(14), dpToPx(16), dpToPx(14))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E53935")) // rojo
                cornerRadius = dpToPx(12).toFloat()
                setStroke(dpToPx(2), Color.parseColor("#E53935"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, dpToPx(8), 0, 0)
            }
            isClickable = true
        }

        val titleView = TextView(this).apply {
            text = "S.O.S"
            textSize = 18f
            setTypeface(null, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            letterSpacing = 0.2f
        }

        val subtitleView = TextView(this).apply {
            text = "Mantén presionado para enviar"
            textSize = 11f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setPadding(0, dpToPx(4), 0, 0)
        }

        button.addView(titleView)
        button.addView(subtitleView)

        sosButtonView = button
        sosLabelView = subtitleView

        button.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    subtitleView.text = "Enviando SOS..."
                    button.background = GradientDrawable().apply {
                        setColor(Color.parseColor("#B71C1C"))
                        cornerRadius = dpToPx(12).toFloat()
                        setStroke(dpToPx(2), Color.parseColor("#B71C1C"))
                    }
                    sosHoldRunnable = Runnable {
                        Log.d(TAG, "🆘 [SOS] Hold completado - enviando SOS")
                        updateUserStatus(sosEmoji, sosId)
                    }
                    sosHandler.postDelayed(sosHoldRunnable!!, 1000)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    sosHoldRunnable?.let { sosHandler.removeCallbacks(it) }
                    sosHoldRunnable = null
                    subtitleView.text = "Mantén presionado para enviar"
                    button.background = GradientDrawable().apply {
                        setColor(Color.parseColor("#E53935"))
                        cornerRadius = dpToPx(12).toFloat()
                        setStroke(dpToPx(2), Color.parseColor("#E53935"))
                    }
                    true
                }
                else -> false
            }
        }

        return button
    }

    /**
     * Aviso de zona bloqueada — layout programático idéntico al Dialog Flutter:
     * fondo negro sólido, borde menta 40% opacidad, título blanco bold, mensaje
     * blanco 80% opacidad, botón "Entendido" alineado a la derecha en menta.
     */
    private fun showZoneNotAllowedDialog() {
        val dialog = android.app.Dialog(this)
        dialog.requestWindowFeature(android.view.Window.FEATURE_NO_TITLE)

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(20), dpToPx(20), dpToPx(20), dpToPx(16))
            background = GradientDrawable().apply {
                setColor(Color.BLACK)
                cornerRadius = dpToPx(16).toFloat()
                setStroke(dpToPx(1), Color.argb(102, 28, 228, 179)) // #661CE4B3
            }
        }

        val titleView = TextView(this).apply {
            text = "Acción no permitida"
            textSize = 18f
            setTypeface(null, android.graphics.Typeface.BOLD)
            setTextColor(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val messageView = TextView(this).apply {
            text = "No puedes seleccionar zonas manualmente. El estado de zonas se actualiza automáticamente por geofencing."
            textSize = 14f
            setTextColor(Color.argb(204, 255, 255, 255)) // #CCFFFFFF
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dpToPx(12) }
        }

        val buttonContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dpToPx(18) }
        }

        val buttonView = TextView(this).apply {
            text = "Entendido"
            textSize = 14f
            setTypeface(null, android.graphics.Typeface.BOLD)
            setTextColor(Color.parseColor("#1CE4B3"))
            setPadding(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8))
            isClickable = true
            isFocusable = true
            setOnClickListener { dialog.dismiss() }
        }

        buttonContainer.addView(buttonView)
        container.addView(titleView)
        container.addView(messageView)
        container.addView(buttonContainer)

        dialog.setContentView(container)
        dialog.window?.apply {
            setBackgroundDrawable(GradientDrawable().apply { setColor(Color.TRANSPARENT) })
            setLayout(
                (resources.displayMetrics.widthPixels * 0.85).toInt(),
                android.view.WindowManager.LayoutParams.WRAP_CONTENT
            )
        }

        dialog.show()
    }

    private fun updateUserStatus(emoji: String, status: String) {
        Log.d(TAG, "🔥 [HYBRID] Actualizando estado: $emoji ($status)")

        val timestamp = System.currentTimeMillis()
        Log.d(TAG, "📋 [DIAG-BN-WRITE] updateUserStatus: statusType=$status emoji=$emoji timestamp=$timestamp")

        val intent = Intent("com.datainfers.zync.UPDATE_STATUS").apply {
            putExtra("emoji", emoji)
            putExtra("statusType", status)
            setPackage(packageName)
        }
        sendBroadcast(intent)
        Log.d(TAG, "📋 [DIAG-BN-WRITE] broadcast enviado (solo válido si app está viva)")

        val prefs = getSharedPreferences("pending_status", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("statusType", status)
            .putString("emoji", emoji)
            .putLong("timestamp", timestamp)
            .apply()
        Log.d(TAG, "📋 [DIAG-BN-WRITE] pending_status guardado: statusType=$status timestamp=$timestamp")

        val workData = Data.Builder()
            .putString("statusType", status)
            .putString("emoji", emoji)
            .putLong("timestamp", timestamp)
            .build()

        val workRequest = OneTimeWorkRequestBuilder<StatusUpdateWorker>()
            .setInputData(workData)
            .addTag("status_update_$timestamp")
            .build()

        WorkManager.getInstance(this).enqueue(workRequest)
        Log.d(TAG, "📋 [DIAG-BN-WRITE] WorkManager.enqueue → worker encolado con tag=status_update_$timestamp")

        Log.d(TAG, "✅ [HYBRID] Estado enviado - cerrando dialog")
        finish()
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
