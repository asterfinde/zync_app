package com.datainfers.zync

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Router central del canal `nunakin/bridge` v1.
 *
 * Concentra los 7 handlers que hoy viven dispersos en MainActivity.kt.
 * Se instancia en setupBridgeRouter() cuando USE_LEGACY_BRIDGE = false.
 *
 * Día 1: stubs. Días 2-5: implementaciones reales migradas desde MainActivity.
 */
class BridgeRouter(private val context: Context) {

    /** Día 2 — activateSilentMode / deactivateSilentMode */
    fun handleSilentMode(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 3 — updateStatus (StatusUpdateWorker → bridge) */
    fun handleStatus(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 3 — raiseSOS */
    fun handleSOS(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 4 — getCurrentLocation */
    fun handleLocation(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    /** Día 4 — setUserSession / clearSession */
    fun handleSession(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
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
