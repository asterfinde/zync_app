package com.datainfers.zync

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.tasks.Tasks
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

        Log.d(TAG, "💼 [WORKER] Iniciando write directo a Firestore: $statusType (ts: $timestamp)")
        Log.d(TAG, "📋 [DIAG-BN-WRITE] Worker doWork START: statusType=$statusType timestamp=$timestamp")

        // Verificar si Flutter ya procesó el estado al reabrir la app
        val prefs = applicationContext.getSharedPreferences("pending_status", Context.MODE_PRIVATE)
        val pendingTimestamp = prefs.getLong("timestamp", 0L)
        Log.d(TAG, "📋 [DIAG-BN-WRITE] pending_status en SharedPrefs: pendingTimestamp=$pendingTimestamp | workerTimestamp=$timestamp | match=${pendingTimestamp == timestamp}")

        if (pendingTimestamp != timestamp) {
            Log.d(TAG, "✅ [WORKER] Estado ya fue procesado por Flutter — cancelando worker")
            Log.d(TAG, "📋 [DIAG-BN-WRITE] Worker CANCELADO (timestamp mismatch: worker=$timestamp, prefs=$pendingTimestamp)")
            return Result.success()
        }

        return try {
            // Leer userId y circleId desde SQLite Room (sin necesidad de Flutter)
            val state = NativeStateManager.getState(applicationContext)
            val circleId = state?.circleId
            val userId = state?.userId
            Log.d(TAG, "📋 [DIAG-BN-WRITE] NativeStateManager: userId=$userId circleId=$circleId")

            if (circleId.isNullOrEmpty() || userId.isNullOrEmpty()) {
                Log.w(TAG, "⚠️ [WORKER] circleId o userId no disponibles en NativeStateManager")
                Log.w(TAG, "📋 [DIAG-BN-WRITE] FALLA: NativeStateManager vacío — ¿Flutter nunca sincronizó el estado?")
                return Result.failure()
            }

            // Firebase Auth persiste entre sesiones — no requiere Flutter para autenticar
            val currentUser = FirebaseAuth.getInstance().currentUser
            Log.d(TAG, "📋 [DIAG-BN-WRITE] FirebaseAuth.currentUser: ${currentUser?.uid ?: "NULL"}")
            if (currentUser == null) {
                Log.w(TAG, "⚠️ [WORKER] Sin usuario Firebase autenticado")
                Log.w(TAG, "📋 [DIAG-BN-WRITE] FALLA: FirebaseAuth.currentUser es null — token expiró o nunca se autenticó")
                return Result.failure()
            }
            if (currentUser.uid != userId) {
                Log.w(TAG, "⚠️ [WORKER] UID Firebase (${currentUser.uid}) ≠ NativeStateManager ($userId)")
                Log.w(TAG, "📋 [DIAG-BN-WRITE] FALLA: UID mismatch — Firebase=${currentUser.uid} vs Room=$userId")
                return Result.failure()
            }
            Log.d(TAG, "📋 [DIAG-BN-WRITE] Auth OK: uid=${currentUser.uid} coincide con NativeStateManager")

            // Write directo a Firestore — mismo esquema que StatusService.updateUserStatus() en Flutter
            val db = FirebaseFirestore.getInstance()
            val statusData = hashMapOf<String, Any?>(
                "userId"        to userId,
                "statusType"    to statusType,
                "timestamp"     to FieldValue.serverTimestamp(),
                "autoUpdated"   to false,
                "manualOverride" to false,
                "locationUnknown" to false,
                "customEmoji"   to null,
                "zoneName"      to null,
                "zoneId"        to null,
            )

            Tasks.await(
                db.collection("circles")
                    .document(circleId)
                    .update("memberStatus.$userId", statusData)
            )

            // Limpiar pending_status para que Flutter no lo reprocese al reabrir la app
            prefs.edit().clear().apply()

            Log.d(TAG, "✅ [WORKER] '$statusType' escrito en Firestore. Circle: $circleId, User: $userId")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "❌ [WORKER] Error escribiendo a Firestore: ${e.message}", e)
            Result.failure()
        }
    }
}
