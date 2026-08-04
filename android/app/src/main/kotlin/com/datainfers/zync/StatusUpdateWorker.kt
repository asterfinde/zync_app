package com.datainfers.zync

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.tasks.Tasks
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import java.util.concurrent.TimeUnit

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

            // ════════════════════════════════════════════════════════════
            // [FIX] DT-SOS-BN-EMAILGATE — SOS desde BN sin verificar bypasseaba el gate
            // Fecha: 2026-08-04
            // PROBLEMA: StatusService.updateUserStatus() (Dart) bloquea SOS si
            //   !user.emailVerified, pero este Worker escribe a Firestore directo
            //   y nunca replicó ese chequeo — confirmado en device: SOS con
            //   emailVerified=false se escribía igual, con GPS real.
            // SOLUCIÓN: mismo criterio que el lado Dart — flag cacheado de
            //   FirebaseAuth (sin reload()) para no agregar una dependencia de
            //   red a este camino. No es un fallo transitorio: Result.failure()
            //   (sin retry), igual que el resto de los guards de esta función.
            // ════════════════════════════════════════════════════════════
            if (statusType == "sos" && !currentUser.isEmailVerified) {
                Log.w(TAG, "[DIAG-SOS] FAIL — SOS bloqueado: email no verificado (uid=$userId)")
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

            // ════════════════════════════════════════════════════════════
            // [FIX] MS-20260529 — Firestore offline tras Silent Mode prolongado
            // PROBLEMA: Tasks.await(update) bloquea indefinidamente cuando el SDK
            //   de Firestore está en modo offline (Doze >50min en background).
            //   El Worker nunca loggeaba SUCCESS ni EXCEPTION — confirmado con logs
            //   [DIAG-W6 STARTING] sin resolución en 3 Workers paralelos (64min gap).
            // SOLUCIÓN: enableNetwork() con timeout 10s antes del write para despertar
            //   la conexión Firebase. Si la red no está disponible, el timeout lanza
            //   excepción → catch → Result.retry() (ver abajo).
            // ════════════════════════════════════════════════════════════
            Log.d(TAG, "[DIAG-W6] enableNetwork STARTING")
            Tasks.await(db.enableNetwork(), 10, TimeUnit.SECONDS)
            Log.d(TAG, "[DIAG-W6] enableNetwork OK")
            Log.d(TAG, "[DIAG-W6] Firestore.update STARTING — circle=$circleId userId=$userId statusType=$statusType")
            Tasks.await(
                db.collection("circles")
                    .document(circleId)
                    .update("memberStatus.$userId", statusData),
                30, TimeUnit.SECONDS
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
            val flutterPrefs = applicationContext
                .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // ════════════════════════════════════════════════════════════
            // [FIX] Borde verde desincronizado tras pick de BN
            // Fecha: 2026-08-02
            // PROBLEMA: este Worker (único encolador, ver EmojiDialogActivity.kt;
            //   la notificación persistente que lo dispara solo existe con Modo
            //   Silencio activo) solo escribía current_status_id. El indicador de
            //   estado activo (EmojiDialogActivity.kt / in_circle_view.dart)
            //   resuelve con prioridad pre_silent_status_id mientras MS está
            //   activo — nunca se actualizaba, dejando el borde verde congelado
            //   en la selección previa a pesar de que Firestore ya reflejaba la
            //   nueva.
            // SOLUCIÓN: dado que este Worker solo corre con MS activo, actualizar
            //   pre_silent_status_id en cada pick (siempre selección deliberada).
            //   TAMBIÉN actualizar manual_status_id, aunque en el momento de
            //   escribirla MS siga activo y por tanto no gobierne el indicador
            //   todavía: MainActivity.onCreate() autodesactiva MS al reabrir la
            //   app (Regla 1) y borra pre_silent_status_id/is_silent_mode_active
            //   SIN sincronizar manual_status_id (a diferencia de ExitSilentMode,
            //   que sí lo hace). Si luego el usuario reactiva MS sin elegir un
            //   estado nuevo antes, SilentFunctionalityCoordinator siembra el
            //   próximo pre_silent_status_id desde manual_status_id — si quedó
            //   viejo, reintroduce este mismo bug por esa vía.
            // ════════════════════════════════════════════════════════════
            val isSilentModeActive = flutterPrefs.getBoolean(
                SharedKeys.flutter(SharedKeys.IS_SILENT_MODE_ACTIVE), false
            )
            val editor = flutterPrefs.edit()
                .putBoolean(SharedKeys.flutter(SharedKeys.SUPPRESS_NEXT_GEOFENCE_CHECK), true)
                .putString(SharedKeys.flutter(SharedKeys.CURRENT_STATUS_ID), statusType)
                .putString(SharedKeys.flutter(SharedKeys.MANUAL_STATUS_ID), statusType)
            if (isSilentModeActive) {
                editor.putString(SharedKeys.flutter(SharedKeys.PRE_SILENT_STATUS_ID), statusType)
            }
            editor.apply()
            Log.d(TAG, "[DIAG-W6b] SharedPrefs actualizado — manual_status_id='$statusType' pre_silent_status_id=${if (isSilentModeActive) "'$statusType'" else "sin tocar (MS inactivo)"}")

            // Limpiar pending_status para que Flutter no lo reprocese al reabrir la app
            prefs.edit().clear().apply()

            Log.d(TAG, "[DIAG-W6] Firestore.update SUCCESS — '$statusType' escrito. Circle: $circleId. Flag suppress_next_geofence_check=true")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "[DIAG-W7] EXCEPTION: ${e.javaClass.simpleName}: ${e.message}", e)
            // Retry en lugar de failure — errores de red son transitorios.
            // WorkManager reintentará con backoff exponencial (máx 6 veces por defecto).
            Result.retry()
        }
    }
}
