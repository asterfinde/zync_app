package com.datainfers.zync

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * Worker para actualizar estado cuando la app está cerrada
 * Parte del enfoque híbrido: Broadcast inmediato + Cache + WorkManager backup
 */
class StatusUpdateWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {
    
    private val TAG = "StatusUpdateWorker"
    
    override fun doWork(): Result {
        val statusType = inputData.getString("statusType") ?: return Result.failure()
        val timestamp = inputData.getLong("timestamp", 0L)
        
        Log.d(TAG, "💼 [WORKER] Verificando estado pendiente: $statusType (timestamp: $timestamp)")
        
        // Verificar si el estado ya fue actualizado
        val prefs = applicationContext.getSharedPreferences("pending_status", Context.MODE_PRIVATE)
        val pendingStatus = prefs.getString("statusType", null)
        val pendingTimestamp = prefs.getLong("timestamp", 0L)
        
        if (pendingStatus == null || pendingTimestamp != timestamp) {
            Log.d(TAG, "✅ [WORKER] Estado ya fue actualizado - cancelando worker")
            return Result.success()
        }
        
        // El estado aún está pendiente - intentar enviar broadcast de nuevo
        Log.d(TAG, "📡 [WORKER] Estado aún pendiente - enviando broadcast")
        
        val intent = Intent("com.datainfers.zync.UPDATE_STATUS").apply {
            putExtra("emoji", "")
            putExtra("status", statusType)
            setPackage(applicationContext.packageName)
        }
        
        applicationContext.sendBroadcast(intent)
        
        Log.d(TAG, "✅ [WORKER] Broadcast enviado - Flutter actualizará cuando se abra la app")
        return Result.success()
    }
}