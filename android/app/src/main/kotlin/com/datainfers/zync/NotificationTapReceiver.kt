package com.datainfers.zync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receiver que intercepts el tap en la notificación del Modo Silencio.
 *
 * Problema que resuelve (G1.B5):
 * Si la notificación lanzaba EmojiDialogActivity directamente, Android traía
 * el task de MainActivity al primer plano ANTES de que EmojiDialogActivity
 * pudiera escribir modal_was_open=true — onResume() veía modal_was_open=false
 * y desactivaba el Modo Silencio.
 *
 * Solución: este receiver escribe modal_was_open=true PRIMERO y luego lanza
 * EmojiDialogActivity — garantizando que onResume() siempre vea el flag correcto.
 */
class NotificationTapReceiver : BroadcastReceiver() {
    private val TAG = "NotificationTapReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🔔 [SILENT] Tap en notificación recibido — escribiendo modal_was_open=true")

        // Escribir el flag ANTES de lanzar la Activity para que onResume() lo lea correctamente
        context.getSharedPreferences("zync_silent_mode", Context.MODE_PRIVATE)
            .edit().putBoolean("modal_was_open", true).apply()

        Log.d(TAG, "✅ [SILENT] modal_was_open=true escrito — lanzando EmojiDialogActivity")

        val modalIntent = Intent(context, EmojiDialogActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        context.startActivity(modalIntent)
    }
}
