package com.datainfers.zync

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class ZyncStatusWidget : AppWidgetProvider() {
    
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
        val currentEmoji = prefs.getString("currentEmoji", "😊") ?: "😊"
        val circleName = prefs.getString("circleName", "Sin círculo") ?: "Sin círculo"
        val status = prefs.getString("status", "normal") ?: "normal"
        
        val views = RemoteViews(context.packageName, R.layout.zync_status_widget)
        views.setTextViewText(R.id.widget_status_emoji, currentEmoji)
        views.setTextViewText(R.id.widget_circle_name, circleName)
        
        // Cambiar fondo según el estado
        when (status) {
            "success" -> views.setInt(R.id.widget_status_emoji, "setBackgroundColor", android.graphics.Color.GREEN)
            "error" -> views.setInt(R.id.widget_status_emoji, "setBackgroundColor", android.graphics.Color.RED)
            else -> views.setInt(R.id.widget_status_emoji, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
        }
        
        val intent = Intent(context, MainActivity::class.java)
        intent.putExtra("action", "open_from_widget")
        val pendingIntent = PendingIntent.getActivity(
            context, 
            0, 
            intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_status_emoji, pendingIntent)
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}