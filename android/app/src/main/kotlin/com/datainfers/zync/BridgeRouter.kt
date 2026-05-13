package com.datainfers.zync

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Router central del canal `nunakin/bridge` v1.
 *
 * Concentra los 7 handlers que hoy viven dispersos en MainActivity.kt.
 * Se instancia en setupBridgeRouter() cuando USE_LEGACY_BRIDGE = false.
 *
 * Día 1: stubs. Días 2-5: implementaciones reales migradas desde MainActivity.
 *
 * NOTA: requiere Activity (no solo Context) porque `handleSilentMode`
 * llama a `finishAndRemoveTask()` y `startActivity()` para abrir el
 * diálogo de exención de batería.
 */
class BridgeRouter(private val activity: Activity) {

    private val context: Context = activity
    private val tag = "BridgeRouter"

    /**
     * Estado de Silent Mode — fuente de verdad mientras la ruta del bridge
     * esté activa (USE_LEGACY_BRIDGE = false). Restaurado desde SharedPrefs
     * en `MainActivity.onCreate()`. Mientras el flag legacy siga `true`, este
     * campo no se lee — el dueño es el campo homónimo de MainActivity.
     */
    var isSilentModeActive: Boolean = false

    /** Día 2 — activateSilentMode / deactivateSilentMode + battery check/request */
    fun handleSilentMode(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "activateSilentMode" -> {
                // Idempotencia: si ya está activo, cerrar app sin reiniciar el servicio.
                if (isSilentModeActive) {
                    Log.d(tag, "🌙 [SILENT] Ya activo — cerrando app (Regla 2, idempotencia)")
                    result.success(true)
                    activity.finishAndRemoveTask()
                    return
                }
                Log.d(tag, "🌙 [SILENT] Activando Modo Silencio")
                // Exención de batería: se solicita una sola vez, sin bloquear la activación.
                // El diálogo del sistema aparece mientras la app ya se está cerrando.
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!pm.isIgnoringBatteryOptimizations(context.packageName)) {
                    val batteryIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                    }
                    activity.startActivity(batteryIntent)
                }
                KeepAliveService.start(context)
                isSilentModeActive = true

                context.getSharedPreferences("zync_silent_mode", Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(SharedKeys.IS_SILENT_MODE_ACTIVE, true)
                    .apply()

                Log.d(tag, "🌙 [SILENT] isSilentModeActive=true — cerrando app (Regla 2)")
                result.success(true)
                activity.finishAndRemoveTask()
            }
            "deactivateSilentMode" -> {
                Log.d(tag, "🌙 [SILENT] Desactivando Modo Silencio (logout)")
                KeepAliveService.stop(context)
                NotificationManagerCompat.from(context).cancelAll()
                isSilentModeActive = false
                // G2.C1: Limpiar flag persistido en Kotlin SharedPreferences
                context.getSharedPreferences("zync_silent_mode", Context.MODE_PRIVATE)
                    .edit().putBoolean(SharedKeys.IS_SILENT_MODE_ACTIVE, false).apply()
                // [FIX-003] Limpiar también los flags escritos por Flutter SharedPreferences
                context.applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .edit()
                    .remove(SharedKeys.flutter(SharedKeys.IS_SILENT_MODE_ACTIVE))
                    .remove(SharedKeys.flutter(SharedKeys.PRE_SILENT_STATUS_ID))
                    .apply()
                result.success(true)
            }
            "checkBattery" -> {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val isIgnoring = pm.isIgnoringBatteryOptimizations(context.packageName)
                Log.d(tag, "🔋 [SILENT] Battery optimization ignorada: $isIgnoring")
                result.success(isIgnoring)
            }
            "requestBattery" -> {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                }
                activity.startActivity(intent)
                Log.d(tag, "🔋 [SILENT] Solicitando exención de optimización de batería")
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Emite un evento de estado actualizado hacia Flutter via `nunakin/bridge`.
     *
     * Llamado desde los 3 puntos de emisión en MainActivity (BroadcastReceiver,
     * onResume, onNewIntent) cuando USE_LEGACY_BRIDGE = false.
     * Con el flag en true los callers usan com.datainfers.zync/status_update directamente.
     */
    fun emitStatusEvent(messenger: BinaryMessenger, statusId: String) {
        MethodChannel(messenger, "nunakin/bridge").invokeMethod(
            "nativeEvent",
            mapOf("type" to "statusUpdated", "statusId" to statusId)
        )
    }

    /** Día 3 — Flutter→Kotlin: stub. La implementación real (actualizar notif) es Día 4. */
    fun handleStatus(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 3 — Flutter→Kotlin: stub. La lógica real de GPS y Worker se migra en Día 4. */
    fun handleSOS(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 4 — getCurrentLocation */
    fun handleLocation(call: MethodCall, result: MethodChannel.Result) {
        val fineOk = ActivityCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarseOk = ActivityCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (!fineOk && !coarseOk) {
            Log.w(tag, "📍 [LOCATION] Sin permiso ACCESS_FINE_LOCATION ni ACCESS_COARSE_LOCATION")
            result.error("NO_PERMISSION", "Location permission not granted", null)
            return
        }

        val cts = CancellationTokenSource()
        LocationServices.getFusedLocationProviderClient(activity)
            .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cts.token)
            .addOnSuccessListener { location ->
                if (location != null) {
                    Log.d(tag, "📍 [LOCATION] Obtenida: ${location.latitude}, ${location.longitude}")
                    result.success(mapOf("lat" to location.latitude, "lng" to location.longitude))
                } else {
                    Log.w(tag, "📍 [LOCATION] FusedLocationProvider devolvió null")
                    result.error("NULL_LOCATION", "Location is null — GPS disabled or no fix", null)
                }
            }
            .addOnFailureListener { e ->
                Log.e(tag, "📍 [LOCATION] Error: ${e.message}")
                result.error("LOCATION_ERROR", e.message, null)
            }
    }

    /** Día 4 — setUserSession / clearSession */
    fun handleSession(call: MethodCall, result: MethodChannel.Result, messenger: BinaryMessenger) {
        when (call.method) {
            "setUserSession" -> {
                val uid   = call.argument<String>("uid") ?: ""
                val email = call.argument<String>("email") ?: ""

                if (uid.isNotEmpty()) {
                    val existingCircleId = context
                        .getSharedPreferences("worker_state", Context.MODE_PRIVATE)
                        .getString("circleId", "") ?: ""

                    Log.d(tag, "[SESSION] setUserSession: uid=$uid circleId(preserved)=$existingCircleId")
                    NativeStateManager.saveUserState(context, uid, email, existingCircleId)
                    context.getSharedPreferences("worker_state", Context.MODE_PRIVATE)
                        .edit()
                        .putString("userId", uid)
                        .putString("circleId", existingCircleId)
                        .commit()
                    result.success(true)
                } else {
                    Log.w(tag, "[SESSION] setUserSession recibió uid vacío — usar clearSession en su lugar")
                    result.error("INVALID_UID", "uid must not be empty", null)
                }
            }
            "clearSession" -> {
                Log.d(tag, "[SESSION] clearSession — limpiando NativeStateManager")
                NativeStateManager.clear(context)
                emitSessionClearedEvent(messenger)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun emitSessionClearedEvent(messenger: BinaryMessenger) {
        MethodChannel(messenger, "nunakin/bridge").invokeMethod(
            "nativeEvent",
            mapOf("type" to "sessionCleared")
        )
        Log.d(tag, "[SESSION] SessionCleared event emitido hacia Flutter")
    }

    /** Día 5 — registerZone / unregisterZone */
    fun handleGeofencing(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 5 — setBadgeCount */
    fun handleBadge(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }
}
