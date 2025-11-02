package com.datainfers.zync.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

/**
 * Room Database principal de Zync
 * 
 * Versión 1: Solo tabla user_state
 * 
 * Singleton thread-safe con lazy initialization
 */
@Database(
    entities = [UserStateEntity::class],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    
    abstract fun userStateDao(): UserStateDao
    
    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null
        
        /**
         * Obtener instancia singleton de la DB
         * 
         * Thread-safe con double-checked locking
         */
        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: buildDatabase(context).also { INSTANCE = it }
            }
        }
        
        private fun buildDatabase(context: Context): AppDatabase {
            return Room.databaseBuilder(
                context.applicationContext,
                AppDatabase::class.java,
                "zync_native.db"
            )
                .allowMainThreadQueries() // ✅ CRÍTICO: Permitir reads síncronos
                .build()
        }
        
        /**
         * Para testing: limpiar instancia
         */
        fun clearInstance() {
            INSTANCE?.close()
            INSTANCE = null
        }
    }
}
