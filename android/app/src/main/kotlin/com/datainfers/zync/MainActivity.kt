// android/app/src/main/kotlin/com/datainfers/zync/MainActivity.kt

package com.datainfers.zync

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
// CORRECCIÓN: Elimina este import, no existe en Kotlin
// import com.pravera.flutter_foreground_task.FlutterForegroundTask
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "zync/notification"
    private val NOTIFICATION_ID = 1337
    private val NOTIFICATION_CHANNEL_ID = "zync_custom_notification_channel"
    private var customNotificationReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showCustomNotification" -> {
                    showCustomNotification()
                    result.success(null)
                }
                "hideCustomNotification" -> {
                    hideCustomNotification()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun showCustomNotification() {
        val remoteViews = RemoteViews(packageName, R.layout.quick_actions)
        
        val buttonActionMap = mapOf(
            R.id.btn_status_fine to "STATUS_FINE",
            R.id.btn_status_worried to "STATUS_WORRIED",
            R.id.btn_status_location to "STATUS_LOCATION",
            R.id.btn_status_sos to "STATUS_SOS",
            R.id.btn_status_thinking to "STATUS_THINKING"
        )

        for ((buttonId, action) in buttonActionMap) {
            val intent = Intent("ZyncCustomNotification")
            intent.putExtra("action", action)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                buttonId, 
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            remoteViews.setOnClickPendingIntent(buttonId, pendingIntent)
        }

        val notificationBuilder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(remoteViews)
            .setOngoing(true)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())

        if (customNotificationReceiver == null) {
            customNotificationReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val action = intent?.getStringExtra("action")
                    if (action != null) {
                        Log.d("ZyncTrace", "[TRAZA 1/5] Nativo: Clic recibido en BroadcastReceiver. Action: $action. Enviando a Dart...")
                        // CORRECCIÓN: Usa MethodChannel para enviar el evento a Dart
                        val engine = flutterEngine ?: return
                        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                            .invokeMethod("onQuickAction", action)
                    }
                }
            }
            registerReceiver(customNotificationReceiver, IntentFilter("ZyncCustomNotification"))
        }
    }

    private fun hideCustomNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)

        if (customNotificationReceiver != null) {
            unregisterReceiver(customNotificationReceiver)
            customNotificationReceiver = null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Zync Custom Actions"
            val descriptionText = "Canal para la notificación de acciones rápidas."
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}

// package com.datainfers.zync

// import android.app.NotificationChannel
// import android.app.NotificationManager
// import android.app.PendingIntent
// import android.content.BroadcastReceiver
// import android.content.Context
// import android.content.Intent
// import android.content.IntentFilter
// import android.os.Build
// import android.util.Log
// import android.widget.RemoteViews
// import androidx.core.app.NotificationCompat
// import io.flutter.embedding.android.FlutterActivity
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.MethodChannel

// class MainActivity : FlutterActivity() {
//     private val CHANNEL = "zync/notification"
//     private val NOTIFICATION_ID = 1337
//     private val NOTIFICATION_CHANNEL_ID = "zync_custom_notification_channel"
//     private var customNotificationReceiver: BroadcastReceiver? = null

//     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//         super.configureFlutterEngine(flutterEngine)

//         createNotificationChannel()

//         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "showCustomNotification" -> {
//                     showCustomNotification()
//                     result.success(null)
//                 }
//                 "hideCustomNotification" -> {
//                     hideCustomNotification()
//                     result.success(null)
//                 }
//                 else -> {
//                     result.notImplemented()
//                 }
//             }
//         }
//     }

//     private fun showCustomNotification() {
//         val remoteViews = RemoteViews(packageName, R.layout.quick_actions)
        
//         val buttonActionMap = mapOf(
//             R.id.btn_status_fine to "STATUS_FINE",
//             R.id.btn_status_worried to "STATUS_WORRIED",
//             R.id.btn_status_location to "STATUS_LOCATION",
//             R.id.btn_status_sos to "STATUS_SOS",
//             R.id.btn_status_thinking to "STATUS_THINKING"
//         )

//         for ((buttonId, action) in buttonActionMap) {
//             val intent = Intent("ZyncCustomNotification")
//             intent.putExtra("action", action)
//             // CORRECCIÓN: Se corrige el typo de 'Pendingent' a 'PendingIntent'.
//             val pendingIntent = PendingIntent.getBroadcast(
//                 this,
//                 buttonId, 
//                 intent,
//                 PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//             )
//             remoteViews.setOnClickPendingIntent(buttonId, pendingIntent)
//         }

//         val notificationBuilder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
//             .setSmallIcon(R.mipmap.ic_launcher)
//             .setCustomContentView(remoteViews)
//             .setOngoing(true)

//         val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//         notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())

//         if (customNotificationReceiver == null) {
//             customNotificationReceiver = object : BroadcastReceiver() {
//                 override fun onReceive(context: Context?, intent: Intent?) {
//                     val action = intent?.getStringExtra("action")
//                     if (action != null) {
//                         Log.d("ZyncMainActivity", "Notification button clicked. Action: $action")
//                         // CORRECCIÓN: Usa MethodChannel para enviar el evento a Dart
//                         val engine = flutterEngine ?: return
//                         MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
//                             .invokeMethod("onQuickAction", action)
//                     }
//                 }
//             }
//             registerReceiver(customNotificationReceiver, IntentFilter("ZyncCustomNotification"))
//         }
//     }

//     private fun hideCustomNotification() {
//         val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//         notificationManager.cancel(NOTIFICATION_ID)

//         if (customNotificationReceiver != null) {
//             unregisterReceiver(customNotificationReceiver)
//             customNotificationReceiver = null
//         }
//     }

//     private fun createNotificationChannel() {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//             val name = "Zync Custom Actions"
//             val descriptionText = "Canal para la notificación de acciones rápidas."
//             val importance = NotificationManager.IMPORTANCE_LOW
//             val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
//                 description = descriptionText
//             }
//             val notificationManager: NotificationManager =
//                 getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//             notificationManager.createNotificationChannel(channel)
//         }
//     }
// }

