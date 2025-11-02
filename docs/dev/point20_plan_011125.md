# 🚨 PLAN DE ACCIÓN DEFINITIVO - Point 20: Minimización de App

**Fecha:** 01 de Noviembre, 2025  
**Branch:** `feature/point20-minimization-fix`  
**Prioridad:** 🚨 CRÍTICO  
**Estado:** ⚠️ BLOQUEADO - Necesita validación urgente

---

## 📋 RESUMEN EJECUTIVO

### Problema
Al minimizar la app (botón HOME o multitarea) y luego volver a abrirla, la app se reinicia completamente en lugar de mantener el estado anterior.

### Diagnóstico Confirmado
- ✅ Android **DESTRUYE físicamente** la MainActivity al minimizar (confirmado con logs)
- ✅ Causa: Android 11+ mata procesos agresivamente para liberar RAM
- ✅ AndroidManifest flags (`singleTop`, `alwaysRetainTaskState`) son **IGNORADOS**
- ✅ Main thread bloqueado detectado: Skipped 221 frames (~3.6s)

### Solución Implementada (FASE 2B)
- ✅ `SessionCacheService` creado para persistir sesión en SharedPreferences
- ✅ `main.dart` guarda sesión automáticamente al pausar (AppLifecycleState.paused)
- ✅ `auth_wrapper.dart` usa UI Optimista (restaura desde cache instantáneamente)
- ✅ Verificación real de Firebase Auth en background

### ⚠️ ESTADO ACTUAL
**Las pruebas NO confirman mejora de performance prometida.**  
La implementación existe pero **NO cumple los objetivos** de reducir tiempo de restauración.

---

## 🎯 OBJETIVOS DEL PLAN

1. **Validar si la solución implementada funciona correctamente** (Fase 2B)
2. **Identificar por qué NO se ve mejora de performance** (si el diagnóstico es correcto)
3. **Aplicar todas las mejoras al `main.dart` original** (actualmente solo en `main_minimal_test.dart`)
4. **Cerrar definitivamente el Point 20** con mediciones confirmadas

---

## 📁 ARCHIVOS INVOLUCRADOS

### Implementados (FASE 2B)
- ✅ `lib/core/services/session_cache_service.dart` - Servicio de cache de sesión
- ✅ `lib/main.dart` - Guarda sesión en `onPause`
- ✅ `lib/features/auth/presentation/pages/auth_wrapper.dart` - UI Optimista con cache
- ✅ `lib/main_minimal_test.dart` - App de pruebas con logging detallado

### Pendientes de Mejorar
- ⏳ `lib/core/services/silent_functionality_coordinator.dart` - Posible bloqueo de main thread
- ⏳ `lib/main.dart` - Necesita optimizaciones adicionales si cache no funciona

---

## 🔬 FASE 1: DIAGNÓSTICO CON APP MINIMAL (30 min)

### Objetivo
Ejecutar `main_minimal_test.dart` con logging automático para medir tiempos reales y confirmar:
1. ¿Se guarda la sesión correctamente al minimizar?
2. ¿Se restaura la sesión correctamente al maximizar?
3. ¿Cuánto tiempo toma cada operación?
4. ¿MainActivity se destruye y recrea?

### Paso 1.1: Ejecutar App Minimal con Logging Automático

El archivo `lib/main_minimal_test.dart` **YA ESTÁ IMPLEMENTADO** y tiene:
- ✅ Timer automático para medir tiempos de pausa/resume
- ✅ Logging detallado de todas las operaciones
- ✅ Medición de SessionCache (save/restore)
- ✅ Medición de Firebase Auth
- ✅ UI con métricas en pantalla

**Comando:**
```bash
flutter run -t lib/main_minimal_test.dart
```

### Paso 1.2: Protocolo de Prueba

1. **Iniciar app minimal:**
   ```bash
   flutter run -t lib/main_minimal_test.dart
   ```

2. **Observar logs iniciales:**
   - Buscar: `🚀 [TEST] ========== INICIO main() ==========`
   - Anotar: Tiempo de Firebase Init, SessionCache Init

3. **Minimizar app:**
   - Presionar botón HOME o multitarea
   - Buscar en logs: `📉 [TEST] ========== APP MINIMIZADA ==========`
   - Verificar: ¿Se guardó la sesión? (`💾 [TEST] Sesión guardada`)
   - Anotar: Tiempo de Cache Save

4. **Esperar 5-10 segundos** (simular uso normal)

5. **Maximizar app:**
   - Abrir la app desde recientes
   - Buscar en logs: `📈 [TEST] ========== APP MAXIMIZADA ==========`
   - Verificar:
     - ¿Se ejecutó `onCreate()` nuevamente? (MainActivity destruida)
     - ¿Se restauró el cache? (`💾 [TEST] Cache restaurado`)
     - Tiempo de Cache Restore
     - Tiempo de Firebase Auth Check
     - Tiempo Total Resume

6. **Revisar pantalla de la app:**
   - ¿Se mantuvieron las métricas anteriores?
   - ¿Resume Count incrementó?
   - ¿Session Cache muestra datos válidos?

### Paso 1.3: Criterios de Éxito

| Métrica | Esperado (FASE 2B) | Realidad | Estado |
|---------|-------------------|----------|--------|
| Cache Save | <50ms | ??? | ⏳ MEDIR |
| Cache Restore | <100ms | ??? | ⏳ MEDIR |
| Firebase Auth Check | <50ms | ??? | ⏳ MEDIR |
| Total Resume | <200ms | ??? | ⏳ MEDIR |
| MainActivity onCreate() | NO (pero sí ocurre) | ??? | ⏳ CONFIRMAR |
| Sesión mantenida | SÍ | ??? | ⏳ VALIDAR |

### Paso 1.4: Registrar Resultados

Crea un archivo de texto con los logs capturados:
```bash
# Desde el directorio del proyecto
flutter run -t lib/main_minimal_test.dart > logs/point20_test_$(date +%Y%m%d_%H%M%S).txt 2>&1
```

O copia manualmente los logs relevantes a un archivo para análisis.

---

## 🔧 FASE 2: ANÁLISIS DE RESULTADOS (15 min)

### Escenario A: SessionCache Funciona Correctamente

**Indicadores:**
- ✅ Cache Save <50ms
- ✅ Cache Restore <100ms
- ✅ Session data válida después de restore
- ✅ Total Resume <200ms

**Conclusión:** La solución FASE 2B funciona. Android destruye el proceso pero la restauración es instantánea.

**Acción:**
1. ✅ Marcar Point 20 como **RESUELTO**
2. ✅ Actualizar BACKLOG.md con estado ✅ COMPLETADO
3. ✅ Documentar métricas finales en `/docs/dev/point20_resultados_011125.md`
4. ⏭️ Pasar a FASE 3: Aplicar al `main.dart` original

---

### Escenario B: SessionCache NO Mejora Performance

**Indicadores:**
- ❌ Cache Restore toma >500ms
- ❌ Total Resume toma >1000ms
- ❌ Session data no se restaura correctamente
- ❌ MainActivity se destruye SIEMPRE

**Posibles Causas:**
1. SharedPreferences es lento en el dispositivo específico
2. Main thread bloqueado por otra operación (SilentFunctionalityCoordinator)
3. Firebase Auth domina el tiempo de restauración
4. El dispositivo/ROM mata el proceso más agresivamente de lo normal

**Acción:**
1. 🔍 Analizar logs detallados de `main_minimal_test.dart`
2. 🔍 Identificar qué operación consume más tiempo
3. ⏭️ Pasar a FASE 3B: Optimizaciones adicionales

---

### Escenario C: MainActivity NO Se Destruye

**Indicadores:**
- ✅ NO aparece `onCreate()` en logs al maximizar
- ✅ App mantiene estado sin necesidad de cache
- ✅ Métricas de pantalla se mantienen intactas

**Conclusión:** El problema es específico del dispositivo de prueba anterior, NO del código.

**Acción:**
1. ✅ Marcar Point 20 como **RESUELTO** (no es bug de código)
2. ✅ Mantener SessionCache como feature adicional de robustez
3. ✅ Actualizar BACKLOG.md con estado ✅ COMPLETADO
4. 📝 Documentar que el problema era específico del dispositivo/ROM

---

## 🚀 FASE 3A: APLICAR AL MAIN ORIGINAL (SI FUNCIONA)

### Objetivo
Trasladar todas las mejoras de `main_minimal_test.dart` al `main.dart` original para que la app completa se beneficie.

### Archivos a Modificar

#### 1. `lib/main.dart` (YA TIENE FASE 2B, revisar completitud)

**Verificar que tenga:**
- ✅ Import de `SessionCacheService`
- ✅ Init de SessionCache en `postFrameCallback`
- ✅ Save de sesión en `didChangeAppLifecycleState(paused)`
- ✅ Logging detallado de tiempos

**Agregar (si falta):**
- ⏳ Timer automático para medir tiempos (como en `main_minimal_test.dart`)
- ⏳ Logging de eventos críticos de lifecycle

#### 2. `lib/features/auth/presentation/pages/auth_wrapper.dart` (YA TIENE UI OPTIMISTA)

**Verificar que tenga:**
- ✅ `FutureBuilder` con `SessionCacheService.restoreSession()`
- ✅ Mostrar HomePage instantáneamente si hay cache
- ✅ `_BackgroundAuthVerification` para validar sesión real
- ✅ Fallback a `StreamBuilder` si no hay cache

**Optimizar (si es necesario):**
- ⏳ Reducir tiempo de `_BackgroundAuthVerification`
- ⏳ Pre-cargar servicios críticos en background

#### 3. `lib/core/services/silent_functionality_coordinator.dart` (POSIBLE CUELLO DE BOTELLA)

**Problema Detectado:**
```
I/Choreographer: Skipped 221 frames! (~3.6s de bloqueo)
```

Esto sugiere que `SilentFunctionalityCoordinator` podría estar bloqueando el main thread.

**Acción:**
1. Revisar el código de inicialización
2. Mover operaciones pesadas a `compute()` o `Isolate`
3. Hacer init completamente asíncrono (sin bloquear UI)

### Paso 3A.1: Revisar SilentFunctionalityCoordinator

```bash
# Buscar inicialización bloqueante
grep -n "SilentFunctionalityCoordinator" lib/features/auth/presentation/pages/auth_wrapper.dart
```

**Optimización sugerida:**
```dart
// ANTES (posiblemente bloqueante)
await SilentFunctionalityCoordinator.initialize();

// DESPUÉS (no bloqueante)
Future.microtask(() => SilentFunctionalityCoordinator.initialize());
```

### Paso 3A.2: Aplicar Logging Detallado al Main Original

Agregar al `lib/main.dart` los mismos logs que en `main_minimal_test.dart`:

```dart
// En didChangeAppLifecycleState
if (state == AppLifecycleState.paused) {
  final pauseTime = DateTime.now();
  print('\n📉 [App] ========== APP MINIMIZADA ==========');
  print('🕐 [App] Timestamp: $pauseTime');
  
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final saveStart = DateTime.now();
    await SessionCacheService.saveSession(
      userId: user.uid,
      email: user.email ?? '',
    );
    final saveDuration = DateTime.now().difference(saveStart);
    print('⏱️ [App] Cache Save: ${saveDuration.inMilliseconds}ms');
  }
  print('📉 [App] ====================================\n');
}

if (state == AppLifecycleState.resumed) {
  final resumeTime = DateTime.now();
  print('\n📈 [App] ========== APP MAXIMIZADA ==========');
  print('🕐 [App] Timestamp: $resumeTime');
  
  final restoreStart = DateTime.now();
  final session = await SessionCacheService.restoreSession();
  final restoreDuration = DateTime.now().difference(restoreStart);
  print('⏱️ [App] Cache Restore: ${restoreDuration.inMilliseconds}ms');
  print('💾 [App] Session: ${session?["userId"] ?? "NULL"}');
  print('📈 [App] ====================================\n');
}
```

### Paso 3A.3: Testing del Main Original

1. Ejecutar app completa:
   ```bash
   flutter run
   ```

2. Repetir protocolo de prueba de FASE 1 (minimizar/maximizar)

3. Comparar métricas con `main_minimal_test.dart`

4. Validar que HomePage se muestra instantáneamente

---

## 🔧 FASE 3B: OPTIMIZACIONES ADICIONALES (SI NO FUNCIONA)

### Si SessionCache NO resuelve el problema, aplicar:

#### Optimización 1: Lazy Initialization Completa

Mover **TODAS** las inicializaciones pesadas fuera del main thread:

```dart
// En main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // SOLO Firebase (esencial)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Renderizar UI INMEDIATAMENTE
  runApp(const ProviderScope(child: MyApp()));
  
  // TODO lo demás en background
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.wait([
      SessionCacheService.init(),
      di.init(),
      PersistentCache.init(),
    ]);
  });
}
```

#### Optimización 2: Comentar SilentFunctionalityCoordinator (Testing)

Temporalmente comentar la inicialización para confirmar si es el cuello de botella:

```dart
// En auth_wrapper.dart
// TEMPORALMENTE COMENTADO PARA TESTING
// await SilentFunctionalityCoordinator.initialize();
```

Ejecutar pruebas y medir si el tiempo de resume mejora.

#### Optimización 3: Pre-warm Firebase Auth

Forzar a Firebase a mantener la sesión en memoria:

```dart
// En main.dart, después de Firebase.initializeApp()
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  print('✅ [App] Usuario pre-cargado: ${user.uid}');
}
```

#### Optimización 4: Cache de UI (Hero Widget)

Implementar cache de widgets pesados usando `AutomaticKeepAliveClientMixin`:

```dart
// En HomePage o InCircleView
class _InCircleViewState extends State<InCircleView> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // IMPORTANTE: llamar super
    // ... resto del widget
  }
}
```

---

## 📊 FASE 4: VALIDACIÓN FINAL Y CIERRE (15 min)

### Checklist de Validación

- [ ] **App minimal (`main_minimal_test.dart`) ejecutada y medida**
  - [ ] Logs capturados y analizados
  - [ ] Métricas documentadas en `point20_resultados_011125.md`
  - [ ] Confirmado si SessionCache funciona o no

- [ ] **Decisión tomada** (Escenario A, B o C)
  - [ ] Si funciona: Aplicado al main original
  - [ ] Si no funciona: Optimizaciones adicionales aplicadas
  - [ ] Si no es bug: Documentado y cerrado

- [ ] **Main original optimizado**
  - [ ] SessionCache integrado (si aplica)
  - [ ] Logging detallado agregado
  - [ ] SilentFunctionalityCoordinator optimizado (si aplica)
  - [ ] Pruebas confirmadas en app completa

- [ ] **Documentación actualizada**
  - [ ] `BACKLOG.md` → Point 20 marcado como ✅ COMPLETADO
  - [ ] `point20_resultados_011125.md` creado con métricas finales
  - [ ] Commit con mensaje: `fix(point20): Resolved minimization bug with SessionCache [FINAL]`

### Commit Final

```bash
git add .
git commit -m "fix(point20): Resolved minimization bug - SessionCache + UI Optimista [FINAL]

- ✅ SessionCacheService persists session on pause
- ✅ AuthWrapper restores UI instantly from cache
- ✅ Background verification ensures auth validity
- ✅ MainActivity destruction handled gracefully
- ✅ Performance: Resume <200ms (vs 4000ms before)
- ✅ Main thread optimization: Lazy init + async services

Closes #20"
```

### Merge a Main

```bash
git checkout main
git merge feature/point20-minimization-fix
git push origin main
```

---

## 🎯 RESUMEN DE PRÓXIMOS PASOS INMEDIATOS

### AHORA MISMO (Orden de ejecución):

1. **Ejecutar test minimal** (5 min)
   ```bash
   cd /home/datainfers/projects/zync_app
   flutter run -t lib/main_minimal_test.dart
   ```

2. **Minimizar → Maximizar → Capturar logs** (5 min)
   - Seguir protocolo de FASE 1
   - Copiar logs relevantes a archivo de texto

3. **Analizar resultados** (10 min)
   - Identificar escenario (A, B o C)
   - Decidir siguiente acción

4. **Aplicar solución final** (30 min)
   - Si funciona: FASE 3A (aplicar al main)
   - Si no funciona: FASE 3B (optimizaciones adicionales)

5. **Validar y cerrar** (15 min)
   - Testing final en app completa
   - Actualizar documentación
   - Commit y merge

---

## 📚 REFERENCIAS

### Documentos Relacionados
- `docs/dev/BACKLOG.md` - Estado actual del Point 20
- `docs/dev/SOLUCION_POINT20_FASE2B.md` - Solución implementada
- `docs/dev/performance/CONTRASTE_ANALISIS.md` - Diagnóstico previo
- `docs/dev/HOJA_RUTA_POINT20.md` - Análisis histórico

### Archivos Clave
- `lib/main_minimal_test.dart` - App de testing (USAR ESTO PRIMERO)
- `lib/core/services/session_cache_service.dart` - Servicio de cache
- `lib/main.dart` - Main original (aplicar mejoras aquí)
- `lib/features/auth/presentation/pages/auth_wrapper.dart` - UI Optimista

### Comandos Útiles

```bash
# Ejecutar app minimal
flutter run -t lib/main_minimal_test.dart

# Ejecutar app completa
flutter run

# Capturar logs a archivo
flutter run -t lib/main_minimal_test.dart 2>&1 | tee logs/point20_test.txt

# Ver logs en tiempo real (Android)
adb logcat | grep -E "TEST|MainActivity|SessionCache"

# Limpiar build cache
flutter clean && flutter pub get
```

---

## ✅ CRITERIOS DE ÉXITO FINAL

Point 20 se considera **RESUELTO** cuando:

1. ✅ Se confirma que el problema es del dispositivo (no del código) **O**
2. ✅ SessionCache reduce tiempo de resume a <500ms **O**
3. ✅ Optimizaciones adicionales logran experiencia fluida al maximizar

**Indicador clave:** Usuario maximiza la app y ve HomePage en <1 segundo, sin perder contexto.

---

## 🚨 NOTAS IMPORTANTES

1. **No perder de vista el objetivo:** El usuario debe percibir que la app NO se reinicia.
2. **Métricas realistas:** <200ms es ideal, <500ms es aceptable, >1s NO es aceptable.
3. **El fake (`main_minimal_test.dart`) es para experimentar:** Una vez validado, copiar al main original.
4. **Android destruye el proceso: esto es NORMAL.** La solución es hacer la restauración instantánea, no evitar la destrucción.
5. **Si SessionCache no funciona, NO rendirse:** Hay más optimizaciones posibles (Lazy Init, Hero Widgets, etc.)

---

**FIN DEL PLAN DE ACCIÓN**

🚀 **EJECUTAR AHORA:** `flutter run -t lib/main_minimal_test.dart`
