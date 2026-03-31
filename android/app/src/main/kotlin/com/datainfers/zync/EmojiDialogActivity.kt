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
import java.util.concurrent.TimeUnit

/**
 * Modal nativo de Android para selección de emojis
 * Lee emojis desde SharedPreferences (cache Firebase sincronizado por Flutter)
 * Idéntico en contenido al StatusSelectorOverlay de Flutter
 */
class EmojiDialogActivity : Activity() {
    private val TAG = "EmojiDialogActivity"

    // Emojis cargados desde Firebase cache
    private lateinit var emojis: List<Triple<String, String, String>>

    // SOS press & hold
    private val sosHandler = Handler(Looper.getMainLooper())
    private var sosHoldRunnable: Runnable? = null
    private var sosButtonView: LinearLayout? = null
    private var sosLabelView: TextView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "⚡ [NATIVE] Abriendo dialog nativo de emojis...")

        emojis = loadEmojisFromCache()
        setupActivityUI()
    }

    override fun onDestroy() {
        sosHoldRunnable?.let { sosHandler.removeCallbacks(it) }
        super.onDestroy()
    }

    /**
     * Carga emojis desde SharedPreferences (sincronizados desde Firebase por Flutter)
     */
    private fun loadEmojisFromCache(): List<Triple<String, String, String>> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cachedJson = prefs.getString("flutter.predefined_emojis", null)

        if (cachedJson != null) {
            try {
                Log.d(TAG, "📦 [CACHE] JSON encontrado: ${cachedJson.take(100)}...")

                val emojiList = mutableListOf<Triple<String, String, String>>()

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

                        if (id.isNotEmpty() && emoji.isNotEmpty()) {
                            emojiList.add(Triple(emoji, shortLabel, id))
                        }
                    }
                }

                if (emojiList.isNotEmpty()) {
                    Log.d(TAG, "✅ [CACHE] ${emojiList.size} emojis cargados desde Firebase cache")
                    return emojiList
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ [CACHE] Error parseando: ${e.message}")
            }
        }

        // Fallback: idéntico a StatusType.fallbackPredefined en user_status.dart
        Log.d(TAG, "⚠️ [CACHE] Sin cache, usando fallback")
        return listOf(
            Triple("🙂", "Bien", "fine"),
            Triple("🔴", "Ocupado", "busy"),
            Triple("🟡", "Ausente", "away"),
            Triple("🔕", "No molestar", "do_not_disturb"),
            Triple("🏠", "Casa", "home"),
            Triple("🏫", "Colegio", "school"),
            Triple("🎓", "Universidad", "university"),
            Triple("🏢", "Trabajo", "work"),
            Triple("🏥", "Consulta", "medical"),
            Triple("📅", "Reunión", "meeting"),
            Triple("📚", "Estudia", "studying"),
            Triple("🍽️", "Comiendo", "eating"),
            Triple("💪", "Ejercicio", "exercising"),
            Triple("🚗", "Camino", "driving"),
            Triple("🚶", "Caminando", "walking"),
            Triple("🚌", "Transporte", "public_transport"),
            Triple("🆘", "SOS", "sos")
        )
    }

    private fun setupActivityUI() {
        // SOS separado del grid principal
        val mainEmojis = emojis.filter { (_, _, id) -> id != "sos" }
        val sosItem = emojis.find { (_, _, id) -> id == "sos" }

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
            setPadding(dpToPx(12), dpToPx(12), dpToPx(12), dpToPx(12))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F21E1E1E"))
                cornerRadius = dpToPx(20).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#80616161"))
            }
            val params = FrameLayout.LayoutParams(
                dpToPx(340),
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
                setMargins(dpToPx(32), dpToPx(32), dpToPx(32), dpToPx(32))
            }
            layoutParams = params
            isClickable = true
        }

        // ScrollView con el grid
        val scrollView = android.widget.ScrollView(this).apply {
            val maxHeightDp = (65 * 4) + (10 * 4) + 40
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(maxHeightDp)
            )
            isVerticalScrollBarEnabled = true
            scrollBarStyle = android.view.View.SCROLLBARS_OUTSIDE_OVERLAY
        }

        // Grid con emojis (sin SOS)
        val gridLayout = GridLayout(this).apply { columnCount = 4 }

        mainEmojis.forEach { (emoji, label, statusId) ->
            val container = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(dpToPx(4), dpToPx(6), dpToPx(4), dpToPx(6))
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#99424242"))
                    cornerRadius = dpToPx(12).toFloat()
                    setStroke(dpToPx(1), Color.parseColor("#66757575"))
                }
                foreground = android.graphics.drawable.RippleDrawable(
                    android.content.res.ColorStateList.valueOf(Color.parseColor("#1CE4B3")),
                    null,
                    GradientDrawable().apply {
                        setColor(Color.WHITE)
                        cornerRadius = dpToPx(12).toFloat()
                    }
                )
                layoutParams = GridLayout.LayoutParams().apply {
                    width = dpToPx(65)
                    height = dpToPx(65)
                    setMargins(dpToPx(5), dpToPx(5), dpToPx(5), dpToPx(5))
                }
                isClickable = true
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
            container.setOnClickListener {
                container.background = GradientDrawable().apply {
                    setColor(Color.parseColor("#1CE4B3"))
                    cornerRadius = dpToPx(12).toFloat()
                }
                container.postDelayed({ updateUserStatus(emoji, statusId) }, 150)
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

    private fun updateUserStatus(emoji: String, status: String) {
        Log.d(TAG, "🔥 [HYBRID] Actualizando estado: $emoji ($status)")

        val timestamp = System.currentTimeMillis()

        val intent = Intent("com.datainfers.zync.UPDATE_STATUS").apply {
            putExtra("emoji", emoji)
            putExtra("status", status)
            setPackage(packageName)
        }
        sendBroadcast(intent)

        val prefs = getSharedPreferences("pending_status", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("statusType", status)
            .putString("emoji", emoji)
            .putLong("timestamp", timestamp)
            .apply()

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

        Log.d(TAG, "✅ [HYBRID] Estado enviado - cerrando dialog")
        finish()
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
