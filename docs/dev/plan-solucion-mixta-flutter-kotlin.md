/home/datainfers/projects/zync_app/docs/dev/fase1-instrucciones-prueba.md# Plan: Solución Mixta Flutter/Kotlin para Point 20

**Fecha**: 2025-11-01  
**Problema**: App se reinicia completamente al minimizar/maximizar (5+ segundos de delay)  
**Causa**: Android mata el proceso, Flutter tarda 5s en inicializar desde cero  
**Solución**: Arquitectura mixta - UI en Flutter, lifecycle crítico en Kotlin nativo

---

## 🎯 Objetivos

1. **Mantener proceso vivo** con keep-alive service nativo
2. **Guardar estado inmediatamente** sin esperar a Flutter
3. **Restaurar instantáneamente** (~100ms vs 5s actual)
4. **NO reescribir la app** - solo mover lógica crítica a Kotlin

---

## ✅ Ventajas de la Solución Mixta

- **No se pierde trabajo actual**: UI Flutter permanece intacta
- **Performance nativo**: Inicio y background services optimizados
- **Ya tenemos infraestructura**: MethodChannel en uso (MainActivity.kt)
- **Escalable**: Permite migrar más funcionalidad crítica gradualmente

---

## ⏱️ Estimación de Tiempo

| Fase | Descripción | Tiempo | Prioridad |
|------|-------------|--------|-----------|
| **Fase 1** | Keep-alive nativo | 30 min | 🔴 CRÍTICA |
| **Fase 2** | Persistencia nativa | 1 hora | 🟠 ALTA |
| **Fase 3** | Comunicación Flutter ↔ Kotlin | 1 hora | 🟡 MEDIA |
| **Testing** | Pruebas y validación | 30 min | 🟢 BAJA |
| **TOTAL** | Implementación básica funcional | **2-3 horas** | |

### Extensiones Opcionales (1-2 días adicionales)

- Persistencia SQLite Room (más rápido que SharedPreferences)
- Manejo robusto de edge cases
- Sincronización bidireccional completa
- Documentación exhaustiva

---

## 🚀 Fase 1: Keep-Alive Nativo (30 min) - CRÍTICO

### Objetivo
Iniciar el servicio keep-alive DESDE KOTLIN, sin esperar a Flutter.

### Implementación

#### 1.1 Modificar `MainActivity.kt`

```kotlin
class MainActivity: FlutterActivity() {
    private var isKeepAliveRunning = false
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause() - Iniciando keep-alive NATIVO")
        
        // ✅ KOTLIN inicia servicio INMEDIATAMENTE
        // NO espera a que Flutter procese didChangeAppLifecycleState
        KeepAliveService.start(this)
        isKeepAliveRunning = true
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume() - Deteniendo keep-alive")
        
        if (isKeepAliveRunning) {
            KeepAliveService.stop(this)
            isKeepAliveRunning = false
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Seguridad: asegurar que el servicio esté corriendo
        if (!isKeepAliveRunning) {
            KeepAliveService.start(this)
        }
    }
}
```

#### 1.2 Remover llamadas de Flutter

```dart
// lib/main_minimal_test.dart
// ELIMINAR:
// KeepAliveService.start() en didChangeAppLifecycleState(paused)
// KeepAliveService.stop() en didChangeAppLifecycleState(resumed)

// El servicio ahora se maneja 100% desde Kotlin
```

### Resultado Esperado

- Keep-alive inicia **inmediatamente** al minimizar (0ms delay)
- Android NO mata el proceso
- Swipe izquierda → swipe arriba = app lista instantáneamente

---

## 🗄️ Fase 2: Persistencia Nativa (1 hora) - ALTA PRIORIDAD

### Objetivo
Guardar estado del usuario en SharedPreferences NATIVO sin esperar a Flutter.

### Implementación

#### 2.1 Crear `NativeStateManager.kt`

```kotlin
package com.datainfers.zync

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

object NativeStateManager {
    private const val TAG = "NativeStateManager"
    private const val PREFS_NAME = "zync_native_state"
    private const val KEY_USER_ID = "user_id"
    private const val KEY_USER_EMAIL = "user_email"
    private const val KEY_CIRCLE_ID = "circle_id"
    private const val KEY_LAST_SAVE = "last_save"
    
    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    
    fun saveUserState(
        context: Context,
        userId: String,
        email: String = "",
        circleId: String = ""
    ) {
        try {
            val start = System.currentTimeMillis()
            
            getPrefs(context).edit().apply {
                putString(KEY_USER_ID, userId)
                putString(KEY_USER_EMAIL, email)
                putString(KEY_CIRCLE_ID, circleId)
                putString(KEY_LAST_SAVE, System.currentTimeMillis().toString())
                apply() // async, no bloquea
            }
            
            val duration = System.currentTimeMillis() - start
            Log.d(TAG, "✅ Estado guardado en ${duration}ms: $userId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error guardando estado: ${e.message}")
        }
    }
    
    fun getUserId(context: Context): String? {
        return getPrefs(context).getString(KEY_USER_ID, null)
    }
    
    fun hasValidState(context: Context): Boolean {
        val userId = getUserId(context)
        return !userId.isNullOrEmpty()
    }
}
```

#### 2.2 Integrar en `MainActivity.kt`

```kotlin
class MainActivity: FlutterActivity() {
    private var currentUserId: String? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Verificar si hay estado guardado
        currentUserId = NativeStateManager.getUserId(this)
        if (currentUserId != null) {
            Log.d(TAG, "✅ Estado nativo encontrado: $currentUserId")
        }
    }
    
    override fun onPause() {
        super.onPause()
        
        // Guardar estado INMEDIATAMENTE (no esperar a Flutter)
        currentUserId?.let {
            NativeStateManager.saveUserState(this, it)
        }
        
        KeepAliveService.start(this)
    }
}
```

#### 2.3 MethodChannel para sincronización Flutter → Kotlin

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    // Canal para que Flutter notifique cambios de estado
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zync/native_state")
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "setUserId" -> {
                    val userId = call.argument<String>("userId")
                    val email = call.argument<String>("email") ?: ""
                    val circleId = call.argument<String>("circleId") ?: ""
                    
                    if (userId != null) {
                        currentUserId = userId
                        NativeStateManager.saveUserState(this, userId, email, circleId)
                        result.success(true)
                    } else {
                        result.error("INVALID", "userId no puede ser null", null)
                    }
                }
                "getUserId" -> {
                    result.success(currentUserId)
                }
                else -> result.notImplemented()
            }
        }
}
```

### Resultado Esperado

- Estado guardado en **<10ms** (vs 60ms actual de Flutter)
- Persiste incluso si Flutter crashea
- Disponible INMEDIATAMENTE al reiniciar

---

## 🔄 Fase 3: Comunicación Flutter ↔ Kotlin (1 hora) - MEDIA PRIORIDAD

### Objetivo
Mantener sincronizado el estado entre Flutter y Kotlin.

### Implementación

#### 3.1 Servicio Flutter: `native_state_bridge.dart`

```dart
// lib/core/services/native_state_bridge.dart

import 'package:flutter/services.dart';
import 'dart:developer';

/// Puente de comunicación con el estado nativo de Kotlin
/// 
/// Sincroniza userId, email, circleId entre Flutter y Android nativo
class NativeStateBridge {
  static const _channel = MethodChannel('zync/native_state');

  /// Notificar a Kotlin que el usuario cambió (login, logout, etc)
  static Future<void> setUserId({
    required String userId,
    String email = '',
    String circleId = '',
  }) async {
    try {
      log('[NativeState] 📤 Enviando a Kotlin: $userId');
      await _channel.invokeMethod('setUserId', {
        'userId': userId,
        'email': email,
        'circleId': circleId,
      });
      log('[NativeState] ✅ Kotlin actualizado');
    } catch (e) {
      log('[NativeState] ❌ Error sincronizando: $e');
    }
  }

  /// Obtener userId desde Kotlin (útil en cold start)
  static Future<String?> getUserId() async {
    try {
      final userId = await _channel.invokeMethod<String>('getUserId');
      log('[NativeState] 📥 Recibido de Kotlin: $userId');
      return userId;
    } catch (e) {
      log('[NativeState] ❌ Error obteniendo userId: $e');
      return null;
    }
  }
}
```

#### 3.2 Integrar en AuthProvider

```dart
// lib/features/auth/presentation/provider/auth_provider.dart

import 'package:zync_app/core/services/native_state_bridge.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  
  void _onAuthStateChanged(firebase.User? firebaseUser) async {
    if (firebaseUser != null) {
      final result = await _getCurrentUser(NoParams());
      result.fold(
        (failure) => /* ... */,
        (user) {
          if (user != null) {
            // ✅ NUEVO: Sincronizar con Kotlin
            NativeStateBridge.setUserId(
              userId: user.id,
              email: user.email,
              circleId: user.circleId ?? '',
            );
            
            state = Authenticated(user);
          }
        },
      );
    } else {
      // ✅ NUEVO: Limpiar estado nativo al logout
      NativeStateBridge.setUserId(userId: '');
      state = Unauthenticated();
    }
  }
}
```

#### 3.3 Cold Start Optimization

```dart
// lib/main.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase init...
  
  // SessionCache init...
  
  // ✅ NUEVO: Verificar si hay estado nativo disponible
  final nativeUserId = await NativeStateBridge.getUserId();
  if (nativeUserId != null && nativeUserId.isNotEmpty) {
    log('🚀 [main] Estado nativo encontrado: $nativeUserId');
    // Flutter puede usar esto para restaurar más rápido
  }
  
  runApp(const ProviderScope(child: MyApp()));
}
```

### Resultado Esperado

- Flutter y Kotlin siempre sincronizados
- Cold start más rápido (Flutter puede saltear inicialización)
- Estado consistente incluso con crashes

---

## 🧪 Testing

### Escenario 1: Swipe Izquierda → Swipe Arriba
**Antes**: 5+ segundos (onCreate completo)  
**Después**: <500ms (onResume instantáneo)

### Escenario 2: Proceso Killed por Android
**Antes**: Estado perdido, reinicio completo  
**Después**: Estado restaurado desde Kotlin en <100ms

### Escenario 3: Login/Logout
**Antes**: Solo Flutter conoce el estado  
**Después**: Kotlin sincronizado automáticamente

---

## 📊 Métricas de Éxito

| Métrica | Actual | Target | Esperado |
|---------|--------|--------|----------|
| **Time to Resume** | 5000ms | <500ms | ✅ 100-300ms |
| **State Persistence** | 60ms | <10ms | ✅ 5-8ms |
| **Process Survival** | 0% | >95% | ✅ 98% |
| **Cold Start** | 5000ms | <2000ms | ✅ 1500ms |

---

## 🚨 Riesgos y Mitigaciones

### Riesgo 1: Desincronización Flutter ↔ Kotlin
**Mitigación**: Kotlin es source of truth, Flutter sincroniza en cada cambio

### Riesgo 2: SharedPreferences lento
**Mitigación**: Usar `apply()` (async) en vez de `commit()` (sync)

### Riesgo 3: Keep-alive service mata batería
**Mitigación**: Notificación LOW priority, detener al resumir app

---

## 📝 Notas de Implementación

- **NO reescribir UI**: Flutter sigue manejando toda la interfaz
- **Kotlin solo para lifecycle**: onPause, onResume, onDestroy
- **MethodChannel ligero**: Solo para sincronizar userId/email/circleId
- **Compatibilidad**: Funciona con arquitectura actual (Clean Architecture)

---

## 🔄 Siguientes Pasos (Post-Implementación)

1. **Monitorear métricas** de performance en producción
2. **Considerar SQLite Room** si SharedPreferences no es suficiente
3. **Migrar funcionalidad crítica adicional** a Kotlin si necesario
4. **Documentar patrones** para futuros servicios nativos

---

## 🎯 Conclusión

La solución mixta Flutter/Kotlin es:
- ✅ **Pragmática**: No descarta el trabajo actual
- ✅ **Rápida**: 2-3 horas de implementación
- ✅ **Efectiva**: Resuelve el problema de raíz
- ✅ **Escalable**: Permite migrar más funcionalidad gradualmente

**Recomendación**: Implementar Fase 1 y 2 INMEDIATAMENTE. Fase 3 puede ser iterativa.
