package com.datainfers.zync.db

import androidx.room.*

/**
 * DAO (Data Access Object) para acceder al estado del usuario
 * 
 * Operaciones:
 * - insert: Guardar/actualizar estado (upsert automático)
 * - get: Leer estado actual (síncrono, <5ms)
 * - clear: Limpiar al logout
 */
@Dao
interface UserStateDao {
    
    /**
     * Guardar estado del usuario (reemplaza si existe)
     * OnConflictStrategy.REPLACE = UPSERT automático
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insert(state: UserStateEntity)
    
    /**
     * Obtener estado actual (síncrono)
     * Retorna null si no hay usuario guardado
     */
    @Query("SELECT * FROM user_state WHERE id = 1 LIMIT 1")
    fun get(): UserStateEntity?
    
    /**
     * Limpiar estado (logout)
     */
    @Query("DELETE FROM user_state")
    fun clear()
    
    /**
     * Verificar si existe estado guardado
     */
    @Query("SELECT COUNT(*) FROM user_state WHERE id = 1")
    fun hasState(): Int
}
