package com.datainfers.zync

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class ZyncStatusWidgetProvider : AppWidgetProvider() {
    
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val sharedPrefs = context.getSharedPreferences(HomeWidgetPlugin.DATA_PREFERENCES, Context.MODE_PRIVATE)
        val status = sharedPrefs.getString("status", "😊")
        val circle = sharedPrefs.getString("circle", "Sin círculo")
        
        val views = RemoteViews(context.packageName, R.layout.zync_status_widget)
        views.setTextViewText(R.id.widget_status_emoji, status)
        views.setTextViewText(R.id.widget_circle_name, circle)
        
        // Set up click intent to open the app
        val intent = HomeWidgetPlugin.getLaunchAppIntent(context, MainActivity::class.java)
        val pendingIntent = HomeWidgetPlugin.getLaunchAppPendingIntent(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}