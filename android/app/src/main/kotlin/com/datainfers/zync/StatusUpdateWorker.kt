package com.datainfers.zync

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

/**
 * Worker para actualizar estado en Firestore cuando la app está cerrada.
 *
 * Antes: re-enviaba un broadcast que nadie escuchaba con app cerrada.
 * Ahora: escribe DIRECTAMENTE a Firestore usando Firebase SDK nativo +
 *        NativeStateManager (userId/circleId en SQLite Room, sin Flutter).
 *
 * Fix MS3.03/MS3.04/MS3.05: seleccionar emoji desde BN con app cerrada
 * ahora actualiza Firebase de inmediato en lugar de esperar a que Flutter abra.
 */
class StatusUpdateWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    private val TAG = "StatusUpdateWorker"

    override fun doWork(): Result {
        val statusType = inputData.getString("statusType") ?: return Result.failure()
        val timestamp = inputData.getLong("timestamp", 0L)

        Log.d(TAG, "[DIAG-W1] doWork START — input ts=$timestamp status=$statusType")

        // Verificar si Flutter ya procesó el estado al reabrir la app
        val prefs = applicationContext.getSharedPreferences("pending_status", Context.MODE_PRIVATE)
        val pendingTimestamp = prefs.getLong("timestamp", 0L)

        Log.d(TAG, "[DIAG-W2] pendingTs=$pendingTimestamp == enqueueTs=$timestamp ? ${pendingTimestamp == timestamp}")
        if (pendingTimestamp != timestamp) {
            Log.d(TAG, "[DIAG-W2] BAIL-OUT — timestamp mismatch")
            return Result.success()
        }

        return try {
            // Leer userId y circleId — NativeStateManager primero, SharedPreferences como fallback.
            // NativeStateManager usa Room (async write) y puede estar vacío si el proceso murió
            // antes de que el coroutine terminara. SharedPreferences usa commit() (sync) y
            // siempre tiene los valores del último setUserId exitoso desde Flutter.
            val state = NativeStateManager.getState(applicationContext)
            val nativeUserId = state?.userId
            val nativeCircleId = state?.circleId
            Log.d(TAG, "[DIAG-W3] NativeState: userId=$nativeUserId circleId=$nativeCircleId")

            var userId = nativeUserId
            var circleId = nativeCircleId

            if (circleId.isNullOrEmpty() || userId.isNullOrEmpty()) {
                val fallback = applicationContext.getSharedPreferences("worker_state", Context.MODE_PRIVATE)
                userId = fallback.getString("userId", null)
                circleId = fallback.getString("circleId", null)
                Log.d(TAG, "[DIAG-W4] Fallback worker_state: userId=$userId circleId='$circleId' (empty=${circleId.isNullOrEmpty()})")
            }

            if (circleId.isNullOrEmpty() || userId.isNullOrEmpty()) {
                Log.w(TAG, "[DIAG-W4] FAIL — circleId o userId no disponibles en ninguna fuente")
                return Result.failure()
            }

            // Firebase Auth persiste entre sesiones — no requiere Flutter para autenticar
            val currentUser = FirebaseAuth.getInstance().currentUser
            Log.d(TAG, "[DIAG-W5] FirebaseAuth.currentUser?.uid=${currentUser?.uid} expected=$userId")
            if (currentUser == null) {
                Log.w(TAG, "[DIAG-W5] FAIL — Sin usuario Firebase autenticado")
                return Result.failure()
            }
            if (currentUser.uid != userId) {
                Log.w(TAG, "[DIAG-W5] FAIL — UID mismatch: Firebase=${currentUser.uid} NativeState=$userId")
                return Result.failure()
            }

            // Write directo a Firestore — mismo esquema que StatusService.updateUserStatus() en Flutter

            // ════════════════════════════════════════════════════════════
            // [FIX AUTH-20260504-013] GPS capturado en foreground (Activity)
            // Fecha: 2026-05-04
            // PROBLEMA: Worker corre en background; Android 10+ retorna null
            //   en getCurrentLocation sin ACCESS_BACKGROUND_LOCATION (44ms).
            // SOLUCIÓN: EmojiDialogActivity captura GPS en foreground y pasa
            //   lat/lng via inputData. Worker solo lee — sin acceso a Location.
            // ════════════════════════════════════════════════════════════
            var sosLat: Double? = null
            var sosLng: Double? = null
            if (statusType == "sos") {
                val latIn = inputData.getDouble("sosLat", Double.NaN)
                val lngIn = inputData.getDouble("sosLng", Double.NaN)
                if (!latIn.isNaN() && !lngIn.isNaN()) {
                    sosLat = latIn
                    sosLng = lngIn
                    Log.d(TAG, "[DIAG-SOS] GPS recibido desde Activity (foreground): lat=$sosLat lng=$sosLng")
                } else {
                    Log.w(TAG, "[DIAG-SOS] No coordenadas en inputData — SOS sin GPS")
                }
            }

            val db = FirebaseFirestore.getInstance()
            val statusData = hashMapOf<String, Any?>(
                "userId"        to userId,
                "statusType"    to statusType,
                "timestamp"     to FieldValue.serverTimestamp(),
                "autoUpdated"   to false,
                "manualOverride" to true,
                "locationUnknown" to false,
                "customEmoji"   to null,
                "zoneName"      to null,
                "zoneId"        to null,
                "coordinates"   to if (statusType == "sos" && sosLat != null && sosLng != null)
                    hashMapOf("latitude" to sosLat, "longitude" to sosLng)
                else null,
            )

            Log.d(TAG, "[DIAG-W6] Firestore.update STARTING — circle=$circleId userId=$userId statusType=$statusType")
            Tasks.await(
                db.collection("circles")
                    .document(circleId)
                    .update("memberStatus.$userId", statusData)
            )

            // ════════════════════════════════════════════════════════════
            // [FIX] Bugs 2 & 3 — Preservar selección BN al reabrir la app
            // Fecha: 2026-04-29
            // PROBLEMA: si el Worker procesa antes de que la app se reabra,
            //   limpia pending_status y MainActivity.onResume() ya no invoca el
            //   canal status_update. Como GeofencingService.suppressNextCheckOnReopen()
            //   solo se llama desde _updateStatusFromNative() en Flutter, el flag
            //   in-memory queda en false y el initial check de geofencing
            //   sobreescribe la selección BN al detectar zona vigente.
            // SOLUCIÓN: persistir un flag en FlutterSharedPreferences que main.dart
            //   leerá antes de runApp() para suprimir el próximo check inicial.
            //   Solo se escribe tras éxito real en Firestore — si el worker falla
            //   o hace bail-out por timestamp mismatch, no se setea (Flutter ya
            //   habrá procesado vía canal e invocado el suppress in-memory).
            // ════════════════════════════════════════════════════════════
            applicationContext
                .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putBoolean("flutter.suppress_next_geofence_check", true)
                .putString("flutter.current_status_id", statusType)
                .apply()

            // Limpiar pending_status para que Flutter no lo reprocese al reabrir la app
            prefs.edit().clear().apply()

            Log.d(TAG, "[DIAG-W6] Firestore.update SUCCESS — '$statusType' escrito. Circle: $circleId. Flag suppress_next_geofence_check=true")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "[DIAG-W7] EXCEPTION: ${e.javaClass.simpleName}: ${e.message}", e)
            Result.failure()
        }
    }
}
