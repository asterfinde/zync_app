# 🗺️ HOJA DE RUTA: Solución Point 20 - Bug de Minimización

**Fecha:** 28 de Octubre, 2025  
**Branch:** `feature/point20-minimization-fix`  
**Problema:** App se reinicia completamente al minimizar/maximizar

---

## 📊 ANÁLISIS DEL ANÁLISIS EXTERNO vs REALIDAD ZYNC

### ✅ Coincidencias (YA implementado en Zync)

| Solución Propuesta | Estado | Ubicación |
|-------------------|--------|-----------|
| `StatefulWidget` en raíz | ✅ LISTO | `main.dart#51-56` |
| `WidgetsBindingObserver` | ✅ LISTO | `main.dart#58-97` |
| `InitState` vs `Build` | ✅ OPTIMIZADO | `main.dart#34-48` |
| AndroidManifest `singleTop` | ✅ PRESENTE (pero ignorado) | `AndroidManifest.xml#24` |
| Cache de recursos | ✅ FUNCIONAL | PersistentCache |
| Gestión de estado global | ✅ RIVERPOD | Ya instalado |

### ❌ Discrepancias Críticas

```
ANÁLISIS EXTERNO: "Problema de gestión de estado ineficiente"
DIAGNÓSTICO REAL: MainActivity se DESTRUYE físicamente + Main thread bloqueado 3.6s
```

**Evidencia (logs reales):**
```
D/MainActivity: onCreate() - App iniciada  ← Activity MUERE y RENACE
I/Choreographer: Skipped 221 frames!       ← 3.68 segundos BLOQUEADOS
```

### 🎯 Soluciones Aplicables (solo 3 de 10)

1. ⭐⭐⭐ **AutomaticKeepAliveClientMixin** - Preservar estado de listas
2. ⭐⭐⭐⭐⭐ **SessionCacheService** - Cache agresivo de sesión
3. ⭐⭐⭐⭐ **UI Optimista** - Mostrar cache mientras actualiza

---

## 🚀 IMPLEMENTACIÓN: 3 FASES

### **FASE 1: DIAGNÓSTICO CONFIRMATORIO** ⏰ 15 minutos

**Objetivo:** Confirmar si el problema es código o dispositivo/Android

#### Paso 1.1: Ejecutar test minimal

```bash
# Ya creado en lib/main_minimal_test.dart
flutter run -t lib/main_minimal_test.dart
```

**Instrucciones:**
1. Observar timestamp en pantalla
2. Presionar HOME (minimizar)
3. Esperar 5-10 segundos
4. Maximizar app
5. Verificar si timestamp cambió

**Interpretar resultados:**
- **Timestamp NO cambió + app vuelve rápido (<500ms):** ✅ Android conserva proceso → FASE 2A
- **Timestamp SÍ cambió + tarda >2s:** ❌ Android mata proceso → FASE 2B

---

### **FASE 2A: OPTIMIZACIÓN DE CÓDIGO** ⏰ 2 horas
*(Solo si FASE 1 muestra que Android NO mata el proceso)*

#### Paso 2A.1: Identificar bloqueo de Main Thread ⭐⭐⭐⭐⭐

**Culpable identificado:** `SilentFunctionalityCoordinator`

```
I/flutter: [SilentCoordinator] ❌ ERROR: Servicios NO inicializados
I/Choreographer: Skipped 221 frames!  ← 3.68 segundos BLOQUEADOS
```

**Acción:** Deshabilitar temporalmente para confirmar

**Archivo:** `lib/features/auth/presentation/pages/auth_wrapper.dart`

**Líneas a comentar:** 111-130

```dart
// ANTES (ACTUAL) - líneas 111-130
Future.microtask(() async {
  try {
    print('🟢 [AuthWrapper] Activando funcionalidad silenciosa en background...');
    await SilentFunctionalityCoordinator.activateAfterLogin();
    await StatusService.initializeStatusListener();
    await AppBadgeService.markAsSeen();
    print('✅ [AuthWrapper] Funcionalidad silenciosa activada en background');
  } catch (e) {
    print('❌ [AuthWrapper] Error activando funcionalidad silenciosa: $e');
    _isSilentFunctionalityInitialized = false;
  }
});

// DESPUÉS (PARA TEST)
Future.microtask(() async {
  print('⚠️ [TEST] SilentFunctionality DESHABILITADA temporalmente');
  // TODO: Re-habilitar después de optimizar
});
```

**Test:**
```bash
flutter run
# Minimizar → Maximizar
# ¿Desaparecieron los "Skipped frames"?
```

**Si desaparecen → Culpable confirmado, continuar con Paso 2A.2**  
**Si persisten → Buscar otro culpable (verificar AuthWrapper StreamBuilder)**

---

#### Paso 2A.2: Optimizar SilentFunctionalityCoordinator

**Estrategia:** Hacer inicialización más ligera y asíncrona

**Archivo:** `lib/core/services/silent_functionality_coordinator.dart`

**Cambios:**

1. **Hacer initialize() completamente asíncrono:**

```dart
// ANTES (líneas 15-47)
static Future<void> initializeServices() async {
  if (_isInitialized) {
    return;
  }
  
  try {
    await NotificationService.initialize();
    await QuickActionsService.initialize();
    await StatusModalService.initialize();
    NotificationService.setQuickActionTapHandler(_handleQuickActionTap);
    _isInitialized = true;
  } catch (e) {
    print('[SilentCoordinator] ❌ Error: $e');
    rethrow;
  }
}

// DESPUÉS (OPTIMIZADO)
static Future<void> initializeServices() async {
  if (_isInitialized) {
    return;
  }
  
  _isInitialized = true; // ← Marcar INMEDIATAMENTE
  
  // ✅ Ejecutar en paralelo (no secuencial)
  await Future.wait([
    NotificationService.initialize(),
    QuickActionsService.initialize(),
    StatusModalService.initialize(),
  ]).catchError((e) {
    print('[SilentCoordinator] ❌ Error: $e');
    _isInitialized = false;
  });
  
  NotificationService.setQuickActionTapHandler(_handleQuickActionTap);
}
```

2. **Hacer activateAfterLogin() no-bloqueante:**

```dart
// ANTES (líneas 61-83)
static Future<void> activateAfterLogin() async {
  if (!_isInitialized) {
    return;
  }
  
  try {
    await NotificationService.showQuickActionNotification();
  } catch (e) {
    print('[SilentCoordinator] ❌ Error: $e');
  }
}

// DESPUÉS (OPTIMIZADO)
static Future<void> activateAfterLogin() async {
  if (!_isInitialized) {
    return;
  }
  
  // ✅ NO AWAIT - ejecutar en background
  NotificationService.showQuickActionNotification().catchError((e) {
    print('[SilentCoordinator] ❌ Error: $e');
  });
}
```

---

#### Paso 2A.3: Optimizar AuthWrapper con cache local

**Archivo:** `lib/features/auth/presentation/pages/auth_wrapper.dart`

**Problema:** Firebase Auth puede hacer network request bloqueante

**Solución:** Cache local del último usuario

```dart
// AGREGAR en _AuthWrapperState (después de línea 29)
class _AuthWrapperState extends State<AuthWrapper> {
  bool _isSilentFunctionalityInitialized = false;
  String? _lastAuthenticatedUserId;
  User? _cachedUser; // ← AGREGAR CACHE LOCAL

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ✅ OPTIMIZACIÓN: Usar cache mientras espera
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Si hay usuario cacheado, mostrar HomePage INMEDIATAMENTE
          if (_cachedUser != null) {
            return const HomePage();
          }
          
          // Si no hay cache, mostrar loading
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1EE9A4)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Restaurando tu círculo...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('❌ [AuthWrapper] Error: ${snapshot.error}');
          return const AuthFinalPage();
        }

        final user = snapshot.data;
        _cachedUser = user; // ← ACTUALIZAR CACHE

        if (user != null) {
          // ... resto del código
```

---

#### Paso 2A.4: Preservar estado con AutomaticKeepAliveClientMixin

**Archivo:** `lib/features/circle/presentation/widgets/in_circle_view.dart`

**Agregar mixin:**

```dart
// ANTES
class _InCircleViewState extends ConsumerState<InCircleView> {
  // ...
}

// DESPUÉS
class _InCircleViewState extends ConsumerState<InCircleView>
    with AutomaticKeepAliveClientMixin { // ← AGREGAR MIXIN
  
  @override
  bool get wantKeepAlive => true; // ← PRESERVAR ESTADO
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // ← CRÍTICO para KeepAlive
    
    // Tu código actual...
  }
}
```

---

### **FASE 2B: MITIGACIÓN LIMITACIÓN ANDROID** ⏰ 3 horas
*(Si FASE 1 muestra que Android SÍ mata el proceso)*

#### Paso 2B.1: Implementar SessionCacheService ⭐⭐⭐⭐⭐

**Crear:** `lib/core/services/session_cache_service.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de cache de sesión para sobrevivir a destrucción de MainActivity
class SessionCacheService {
  static const _USER_ID_KEY = 'cached_user_id';
  static const _USER_EMAIL_KEY = 'cached_user_email';
  static const _CIRCLE_ID_KEY = 'cached_circle_id';
  static const _LAST_SAVE_KEY = 'cached_last_save';

  /// Guardar sesión al pausar app
  static Future<void> saveSession({
    required String userId,
    required String email,
    String? circleId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_USER_ID_KEY, userId);
    await prefs.setString(_USER_EMAIL_KEY, email);
    if (circleId != null) {
      await prefs.setString(_CIRCLE_ID_KEY, circleId);
    }
    await prefs.setString(_LAST_SAVE_KEY, DateTime.now().toIso8601String());
    
    print('💾 [SessionCache] Sesión guardada: $userId');
  }

  /// Restaurar sesión al resumir
  static Future<Map<String, String>?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_USER_ID_KEY);

    if (userId == null) {
      print('💾 [SessionCache] No hay sesión guardada');
      return null;
    }

    final lastSave = prefs.getString(_LAST_SAVE_KEY);
    print('💾 [SessionCache] Sesión restaurada: $userId (guardada: $lastSave)');

    return {
      'userId': userId,
      'email': prefs.getString(_USER_EMAIL_KEY) ?? '',
      'circleId': prefs.getString(_CIRCLE_ID_KEY) ?? '',
    };
  }

  /// Limpiar sesión al logout
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_USER_ID_KEY);
    await prefs.remove(_USER_EMAIL_KEY);
    await prefs.remove(_CIRCLE_ID_KEY);
    await prefs.remove(_LAST_SAVE_KEY);
    
    print('🗑️ [SessionCache] Sesión limpiada');
  }

  /// Verificar si hay sesión guardada
  static Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_USER_ID_KEY);
  }
}
```

---

#### Paso 2B.2: Integrar SessionCache en main.dart

**Archivo:** `lib/main.dart`

**Modificar didChangeAppLifecycleState (líneas 72-97):**

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  
  if (state == AppLifecycleState.paused) {
    print('📱 [App] Went to background - Guardando sesión...');
    PerformanceTracker.onAppPaused();
    
    // ✅ NUEVO: Guardar sesión
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      SessionCacheService.saveSession(
        userId: user.uid,
        email: user.email ?? '',
      ).catchError((e) {
        print('❌ [App] Error guardando sesión: $e');
      });
    }
    
  } else if (state == AppLifecycleState.resumed) {
    print('📱 [App] Resumed from background');
    PerformanceTracker.start('App Maximization');
    PerformanceTracker.onAppResumed();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerformanceTracker.end('App Maximization');
      
      Future.delayed(const Duration(seconds: 1), () {
        final report = PerformanceTracker.getReport();
        debugPrint(report);
      });
    });
  }
}
```

**Agregar import:**
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zync_app/core/services/session_cache_service.dart';
```

---

#### Paso 2B.3: UI Optimista en AuthWrapper

**Archivo:** `lib/features/auth/presentation/pages/auth_wrapper.dart`

**Modificar build() para usar cache primero (líneas 32-94):**

```dart
@override
Widget build(BuildContext context) {
  return FutureBuilder<Map<String, String>?>(
    // ✅ PRIMERO: Intentar restaurar desde cache
    future: SessionCacheService.restoreSession(),
    builder: (context, cacheSnapshot) {
      // Si hay sesión cacheada, mostrar HomePage INMEDIATAMENTE
      if (cacheSnapshot.hasData && cacheSnapshot.data != null) {
        final cachedUserId = cacheSnapshot.data!['userId'];
        print('⚡ [AuthWrapper] Usando sesión cacheada: $cachedUserId');
        
        // Inicializar servicios en background
        if (_lastAuthenticatedUserId != cachedUserId) {
          _lastAuthenticatedUserId = cachedUserId;
          _initializeSilentFunctionalityIfNeeded(cachedUserId!);
        }
        
        // Mostrar HomePage con overlay de sincronización
        return Stack(
          children: [
            const HomePage(),
            // Verificar autenticación real en background
            FutureBuilder<User?>(
              future: Future.value(FirebaseAuth.instance.currentUser),
              builder: (context, authSnapshot) {
                if (authSnapshot.hasData && authSnapshot.data == null) {
                  // Sesión cache inválida, mostrar login
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    SessionCacheService.clearSession();
                  });
                  return const AuthFinalPage();
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      }
      
      // Si no hay cache, usar StreamBuilder normal
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1EE9A4)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Verificando sesión...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            print('❌ [AuthWrapper] Error: ${snapshot.error}');
            return const AuthFinalPage();
          }

          final user = snapshot.data;

          if (user != null) {
            if (_lastAuthenticatedUserId != user.uid) {
              print('✅ [AuthWrapper] Usuario autenticado: ${user.uid}');
              _lastAuthenticatedUserId = user.uid;
              _initializeSilentFunctionalityIfNeeded(user.uid);
            }
            return const HomePage();
          } else {
            if (_lastAuthenticatedUserId != null) {
              print('🔴 [AuthWrapper] Usuario desautenticado');
              _lastAuthenticatedUserId = null;
              _isSilentFunctionalityInitialized = false;
              _cleanupSilentFunctionalityIfNeeded();
            }
            return const AuthFinalPage();
          }
        },
      );
    },
  );
}
```

---

### **FASE 3: VALIDACIÓN Y MÉTRICAS** ⏰ 30 minutos

#### Paso 3.1: Re-ejecutar PerformanceTracker

```bash
flutter run
# Minimizar app
# Esperar 10 segundos
# Maximizar app
# Ver logs de PerformanceTracker
```

**Verificar métricas:**
```
✅ App Maximization: <1500ms (antes: ~4000ms)
✅ Skipped Frames: <50 (antes: 221)
```

---

#### Paso 3.2: Actualizar documentación

**Archivos a actualizar:**

1. **docs/dev/pendings.txt** - Marcar Point 20 como ✅
2. **docs/dev/performance/CONTRASTE_ANALISIS.md** - Agregar sección "SOLUCIÓN IMPLEMENTADA"
3. **Crear:** `docs/dev/SOLUCION_POINT20.md` - Documentar solución final

---

## 📋 CHECKLIST DE IMPLEMENTACIÓN

### FASE 1: Diagnóstico (15 min)
```
□ Ejecutar main_minimal_test.dart
□ Minimizar/Maximizar y medir tiempo
□ Decidir: FASE 2A (código) o FASE 2B (Android)
```

### FASE 2A: Optimización Código (2 horas) - SI Android NO mata proceso
```
□ Deshabilitar SilentFunctionalityCoordinator temporalmente
□ Re-test → ¿Mejora?
□ Optimizar SilentFunctionalityCoordinator (paralelo, no-await)
□ Agregar cache local en AuthWrapper
□ Agregar AutomaticKeepAliveClientMixin a InCircleView
□ Re-test → Medir mejora
```

### FASE 2B: Mitigación Android (3 horas) - SI Android SÍ mata proceso
```
□ Crear SessionCacheService
□ Integrar en main.dart (guardar en pause)
□ Modificar AuthWrapper (UI optimista con cache)
□ Limpiar sesión en logout
□ Re-test → Medir mejora
```

### FASE 3: Validación (30 min)
```
□ Re-ejecutar PerformanceTracker
□ Confirmar: App Maximization <1500ms
□ Confirmar: Skipped frames <50
□ Actualizar pendings.txt
□ Documentar solución
```

---

## 🎯 METAS DE PERFORMANCE

| Métrica | Actual | Meta Conservadora | Meta Optimista |
|---------|--------|------------------|----------------|
| **App Maximization** | ~4000ms | <1500ms | <800ms |
| **Skipped Frames** | 221 | <50 | <20 |
| **Experiencia Usuario** | Muy lenta | Aceptable | Fluida |

---

## 🚦 PRÓXIMO PASO INMEDIATO

**EJECUTA AHORA:**

```bash
# Test diagnóstico
flutter run -t lib/main_minimal_test.dart

# Minimizar → Esperar 5s → Maximizar

# ¿Timestamp cambió?
# → NO: Ir a FASE 2A (optimizar código)
# → SÍ: Ir a FASE 2B (mitigar Android)
```

---

## 💡 NOTAS IMPORTANTES

### Diferencias clave con análisis externo:

1. **AndroidManifest flags NO funcionan** en Android 11+ (ya comprobado)
2. **El problema NO es gestión de estado** Flutter (ya usas Riverpod correctamente)
3. **El culpable es el bloqueo del Main Thread** (3.6s), no la recreación de widgets
4. **Necesitas diagnóstico de dispositivo primero** antes de optimizar ciegamente

### Ventajas de esta hoja de ruta:

✅ Basada en tu diagnóstico real (no asunciones)  
✅ Usa tu código existente (no reescribe desde cero)  
✅ Prioriza por impacto (SessionCache > AndroidManifest)  
✅ Tiene plan A y plan B según diagnóstico  
✅ Incluye métricas medibles de éxito  

---

**¿Listo para comenzar con FASE 1?** 🚀
