package com.datainfers.zync.db

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Entidad Room para persistir el estado del usuario
 * 
 * Guarda userId, email, circleId en SQLite para acceso instantáneo
 * al iniciar la app (mucho más rápido que SharedPreferences)
 */
@Entity(tableName = "user_state")
data class UserStateEntity(
    @PrimaryKey
    val id: Int = 1, // Solo guardamos 1 registro (el usuario actual)
    
    val userId: String,
    val email: String = "",
    val circleId: String = "",
    val lastSaved: Long = System.currentTimeMillis()
)
