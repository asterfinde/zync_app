// android/app/src/main/kotlin/com/datainfers/zync/QuickActionReceiver.kt

package com.datainfers.zync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class QuickActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra("action")
        if (action != null) {
            // Obtener el FlutterEngine en ejecución
            val flutterEngine = FlutterEngineCache.getInstance().get("my_engine_id")
            if (flutterEngine != null) {
                val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zync/notification")
                channel.invokeMethod("onQuickAction", action)
            }
        }
    }
}
