# Sem 3 - Día 5 — Geofencing + Badge + Flag Flip + Cierre de Semana

**Rama:** `refactor/sem3-bridge-geo-badge-close`

**PR:** `refactor(bridge): Sem3 Día5 — geofencing + badge + USE_LEGACY_BRIDGE=false`

**Modelo de implementación:** **Claude Opus 4.7 — obligatorio.** El flip del flag es el momento
de mayor riesgo de toda Sem 3: cualquier canal legacy no cubierto en `setupBridgeRouter` rompe
producción silenciosamente (el canal existe en Dart pero no tiene handler en Kotlin → `MissingPluginException`).
Opus debe razonar sobre CADA caller antes de flipear.

**Fecha planificada:** 2026-05-23 (viernes)

**Base:** PR #168 → commit `f9d6cd2`

---

## Contexto

### Estado del bridge al inicio de Día 5

| Canal / Handler | Estado |
|----------------|--------|
| `nunakin/silent` — Silent Mode | ✅ Día 2 |
| `nunakin/status` — handleStatus | ✅ Día 3 (stub: `notImplemented`) |
| `nunakin/sos` — handleSOS | ✅ Día 3 (stub: `notImplemented`) |
| `nunakin/location` — handleLocation | ✅ Día 4 |
| `nunakin/session` — handleSession | ✅ Día 4 |
| `nunakin/geofencing` — handleGeofencing | 🔲 stub vacío |
| `nunakin/badge` — handleBadge | 🔲 stub vacío |
| `AndroidNativeBridge._handleNativeEvent` → geofenceEntered/Exited | 🔲 no enrutado |
| `USE_LEGACY_BRIDGE` | `true` (producción usa legacy) |

### Hallazgo crítico — canales fuera de los 7

El flip a `USE_LEGACY_BRIDGE = false` hace que `setupBridgeRouter` reemplace a `setupLegacyChannels`
**completamente**. Varios canales en `setupLegacyChannels` NO están entre los 7 del inventario.
Si no se registran también en `setupBridgeRouter`, los callers Dart recibirán `MissingPluginException`:

| Canal legacy | Caller Dart | Estado en setupBridgeRouter hoy |
|-------------|-------------|----------------------------------|
| `com.datainfers.zync/status_modal` | `StatusModalService` | ❌ No registrado |
| `com.datainfers.zync/pending_status` | `StatusService` | ❌ No registrado |
| `zync/native_state` | `NativeStateBridge.dart` | ❌ No registrado (parcialmente cubierto por `nunakin/session`, pero Dart no lo usa aún) |
| `zync/native_shortcuts` | `NativeShortcutService` / `InCircleView` | ❌ No registrado |
| `mini_emoji/notification` | `NotificationService` | ❌ No registrado |
| `com.datainfers.zync/status_update` | Receptor en Flutter (inbound desde Kotlin) | ❌ `onResume` / `BroadcastReceiver` / `onNewIntent` aún usan el canal legacy |

**T3 es la tarea más crítica del día** — antes de flipear el flag, todos estos canales deben
estar activos en `setupBridgeRouter`.

### Geofencing nativo — scope acotado

`GeofencingService.dart` maneja zonas 100% en Dart via `geolocator`. No existe un
`GeofencingBroadcastReceiver.kt` ni registro con `GeofencingClient` del OS Android.
En Día 5 se implementan los handlers de BridgeRouter y se prepara `emitGeofenceEvent()`,
pero **el trigger nativo (BroadcastReceiver + AndroidManifest + ACCESS_BACKGROUND_LOCATION)
se implementa en Sem 4 (contexto Geofencing)**. Las tareas T1 y T2 son funcionales pero no
activan geofencing OS-level.

---

## Restricciones explícitas

| Restricción | Razón |
|-------------|-------|
| **NO remover `setupLegacyChannels` en este PR** | Coexistencia 48h post-flip antes de eliminar legacy |
| **NO implementar `GeofencingBroadcastReceiver.kt` ni AndroidManifest.xml geofencing** | Scope Sem 4 — agrega permisos y riesgo innecesario en Día 5 |
| **NO usar `result.success()` dos veces en el mismo handler** | Causa crash nativo |
| **Verificar en device físico ANTES de flipear el flag** | El flip solo ocurre si los 5 flows E2E pasan |
| **Si algún E2E falla con flag=false: revertir build.gradle, documentar bloqueador** | `USE_LEGACY_BRIDGE=true` es el escape seguro |

---

## T1 — `BridgeRouter.handleGeofencing` (Kotlin)

Implementar `registerZone` / `unregisterZone`. Almacena en memoria para el futuro
`GeofencingBroadcastReceiver` de Sem 4. Agregar `emitGeofenceEvent()` listo para
ser llamado desde ese receiver cuando esté implementado.

```kotlin
// Campo en BridgeRouter:
private val registeredZones = mutableMapOf<String, Triple<Double, Double, Double>>()
// zoneId → (lat, lng, radiusMeters)

fun handleGeofencing(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
        "registerZone" -> {
            val zoneId       = call.argument<String>("zoneId")         ?: return result.error("MISSING_PARAM", "zoneId", null)
            val lat          = call.argument<Double>("lat")             ?: return result.error("MISSING_PARAM", "lat", null)
            val lng          = call.argument<Double>("lng")             ?: return result.error("MISSING_PARAM", "lng", null)
            val radiusMeters = call.argument<Double>("radiusMeters")    ?: return result.error("MISSING_PARAM", "radiusMeters", null)

            registeredZones[zoneId] = Triple(lat, lng, radiusMeters)
            Log.d(tag, "📍 [GEO] registerZone: $zoneId (${lat}, ${lng}) r=${radiusMeters}m")
            result.success(true)
        }
        "unregisterZone" -> {
            val zoneId = call.argument<String>("zoneId") ?: return result.error("MISSING_PARAM", "zoneId", null)
            registeredZones.remove(zoneId)
            Log.d(tag, "📍 [GEO] unregisterZone: $zoneId")
            result.success(true)
        }
        else -> result.notImplemented()
    }
}

/**
 * Emite un evento de transición de zona hacia Flutter via `nunakin/bridge`.
 *
 * Llamar desde GeofencingBroadcastReceiver (Sem 4) cuando el OS Android
 * dispare la transición. En Día 5, este método queda listo pero sin caller.
 */
fun emitGeofenceEvent(messenger: BinaryMessenger, zoneId: String, isEntry: Boolean) {
    MethodChannel(messenger, "nunakin/bridge").invokeMethod(
        "nativeEvent",
        mapOf("type" to if (isEntry) "geofenceEntered" else "geofenceExited", "zoneId" to zoneId)
    )
    Log.d(tag, "📍 [GEO] Emitiendo ${if (isEntry) "GeofenceEntered" else "GeofenceExited"}: $zoneId")
}
```

---

## T2 — `BridgeRouter.handleBadge` (Kotlin)

Almacena el badge count en SharedPrefs. La notificación persistente puede leer este
valor para actualizar su número de badge via `setNumber(count)`.

```kotlin
fun handleBadge(call: MethodCall, result: MethodChannel.Result) {
    val count = call.argument<Int>("count") ?: 0
    Log.d(tag, "🔴 [BADGE] setBadgeCount: $count")
    context.getSharedPreferences("bridge_badge", Context.MODE_PRIVATE)
        .edit().putInt("badge_count", count).apply()
    result.success(true)
}
```

---

## T3 — `setupBridgeRouter`: completar con canales legacy no migrados (Kotlin)

**Esta es la tarea de mayor riesgo del día.** `setupBridgeRouter` debe registrar TODOS
los canales que `setupLegacyChannels` registraba. Los no migrados se copian literalmente;
los migrados ya están cubiertos por `nunakin/bridge`.

Estructura resultante de `setupBridgeRouter`:

```kotlin
private fun setupBridgeRouter(flutterEngine: FlutterEngine) {
    val router    = BridgeRouter(activity = this)
    val messenger = flutterEngine.dartExecutor.binaryMessenger
    activeBridgeRouter   = router
    bridgeBinaryMessenger = messenger

    // ── Canal unificado (los 7 handlers migrados) ──────────────────────
    MethodChannel(messenger, "nunakin/bridge").setMethodCallHandler { call, result ->
        when (call.method) {
            "activateSilentMode"   -> router.handleSilentMode(call, result)
            "deactivateSilentMode" -> router.handleSilentMode(call, result)
            "checkBattery"         -> router.handleSilentMode(call, result)
            "requestBattery"       -> router.handleSilentMode(call, result)
            "updateStatus"         -> router.handleStatus(call, result)
            "raiseSOS"             -> router.handleSOS(call, result)
            "getCurrentLocation"   -> router.handleLocation(call, result)
            "setUserSession" -> {
                router.handleSession(call, result, messenger)
                currentUserId = call.argument<String>("uid")
                if (!currentUserId.isNullOrEmpty()) warmUpModalEngine()
            }
            "clearSession" -> {
                router.handleSession(call, result, messenger)
                currentUserId = null
                destroyModalEngine()
            }
            "registerZone"         -> router.handleGeofencing(call, result)
            "unregisterZone"       -> router.handleGeofencing(call, result)
            "setBadgeCount"        -> router.handleBadge(call, result)
            else                   -> result.notImplemented()
        }
    }

    // ── Canales legacy aún no migrados al bridge ───────────────────────
    // Permanecen aquí hasta que sus callers Dart sean migrados (Sem 4+).
    setupRemainingLegacyChannels(messenger)
}

/**
 * Registra los canales legacy que no tienen equivalente en nunakin/bridge todavía.
 * Se llama desde setupBridgeRouter para que el flag flip no rompa estos callers.
 * Candidatos a migrar en Sem 4: status_modal, pending_status, native_state,
 * native_shortcuts, mini_emoji/notification, status_update.
 */
private fun setupRemainingLegacyChannels(messenger: BinaryMessenger) {
    // Copiar el handler de cada canal desde setupLegacyChannels,
    // sin modificar la lógica interna.
    
    // com.datainfers.zync/status_modal
    MethodChannel(messenger, "com.datainfers.zync/status_modal").setMethodCallHandler { call, result ->
        // ... mismo handler que setupLegacyChannels
    }

    // com.datainfers.zync/pending_status
    MethodChannel(messenger, "com.datainfers.zync/pending_status").setMethodCallHandler { call, result ->
        // ... mismo handler que setupLegacyChannels
    }

    // zync/native_state — callers Dart (NativeStateBridge) aún lo usan directamente
    MethodChannel(messenger, NATIVE_STATE_CHANNEL).setMethodCallHandler { call, result ->
        // ... mismo handler que setupLegacyChannels
    }

    // zync/native_shortcuts
    MethodChannel(messenger, "zync/native_shortcuts").setMethodCallHandler { call, result ->
        // ... mismo handler que setupLegacyChannels
    }

    // mini_emoji/notification
    MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
        // ... mismo handler que setupLegacyChannels
    }
}
```

### Fix adicional: `onResume`, `BroadcastReceiver`, `onNewIntent` (bridge path)

Con `USE_LEGACY_BRIDGE = false`, `onResume()` y el `BroadcastReceiver` deben emitir
el estado pendiente via `router.emitStatusEvent()` en lugar de construir un canal ad-hoc.
Agregar la bifurcación en los 3 puntos de emisión:

```kotlin
// En onResume() — sección "Procesar estado pendiente":
if (pendingStatus != null) {
    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
        if (BuildConfig.USE_LEGACY_BRIDGE) {
            MethodChannel(messenger, "com.datainfers.zync/status_update")
                .invokeMethod("updateStatus", mapOf("statusType" to pendingStatus))
        } else {
            activeBridgeRouter?.emitStatusEvent(messenger, pendingStatus)
        }
        prefs.edit().clear().apply()
    }
}

// Mismo patrón en BroadcastReceiver.onReceive() (línea ~74) y onNewIntent() (línea ~344).
```

---

## T4 — `NativeCommand`: agregar 3 comandos (Dart)

```dart
/// Registra una zona geográfica circular en el handler nativo.
class RegisterZone extends NativeCommand<void> {
  final String zoneId;
  final double lat;
  final double lng;
  final double radiusMeters;
  const RegisterZone({
    required this.zoneId,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });
}

/// Elimina el registro de una zona geográfica.
class UnregisterZone extends NativeCommand<void> {
  final String zoneId;
  const UnregisterZone({required this.zoneId});
}

/// Actualiza el badge count del ícono de la aplicación.
class SetBadgeCount extends NativeCommand<void> {
  final int count;
  const SetBadgeCount(this.count);
}
```

---

## T5 — `AndroidNativeBridge`: completar eventos + 3 comandos (Dart)

### 5a — `_handleNativeEvent`: enrutar geofenceEntered / geofenceExited

```dart
void _handleNativeEvent(Map<dynamic, dynamic> args) {
  final type = args['type'] as String?;
  switch (type) {
    case 'statusUpdated':
      // ... existente
    case 'silentDeactivated':
      // ... existente
    case 'sessionCleared':
      // ... existente
    case 'geofenceEntered':          // ← Día 5
      final zoneId = args['zoneId'] as String?;
      if (zoneId != null) _eventController.add(GeofenceEntered(zoneId));
    case 'geofenceExited':           // ← Día 5
      final zoneId = args['zoneId'] as String?;
      if (zoneId != null) _eventController.add(GeofenceExited(zoneId));
    default:
      break;
  }
}
```

### 5b — `invoke()`: 3 nuevos casos

```dart
case RegisterZone(:final zoneId, :final lat, :final lng, :final radiusMeters):
  await _channel.invokeMethod<void>('registerZone', {
    'zoneId':       zoneId,
    'lat':          lat,
    'lng':          lng,
    'radiusMeters': radiusMeters,
  });
  return null as T;

case UnregisterZone(:final zoneId):
  await _channel.invokeMethod<void>('unregisterZone', {'zoneId': zoneId});
  return null as T;

case SetBadgeCount(:final count):
  await _channel.invokeMethod<void>('setBadgeCount', {'count': count});
  return null as T;
```

---

## T6 — Flag flip: `USE_LEGACY_BRIDGE = false`

Solo proceder si los E2E de T8 pasan **con el flag en false** en el device físico.

```gradle
// android/app/build.gradle — defaultConfig
buildConfigField "boolean", "USE_LEGACY_BRIDGE", "false"
```

**Verificar inmediatamente después del flip:**
1. Compilar: `flutter build apk --debug` sin errores
2. Instalar en device y correr los 5 flows E2E de T8
3. Si algún flow falla → `USE_LEGACY_BRIDGE = true`, documentar bloqueador en
   `docs/dev/refactor-arch-2026-q2/blockers.md`

---

## T7 — Tests unitarios

### Nuevos tests en `android_native_bridge_test.dart`

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 11 | `RegisterZone(zoneId: 'z1', lat: 1.0, lng: 2.0, radiusMeters: 100.0)` | Invoca `registerZone` con args correctos |
| 12 | `UnregisterZone(zoneId: 'z1')` | Invoca `unregisterZone` con `{zoneId: 'z1'}` |
| 13 | `SetBadgeCount(3)` | Invoca `setBadgeCount` con `{count: 3}` |

### Nuevos tests en `android_native_bridge_test.dart` (eventos)

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 14 | Kotlin emite `{type: geofenceEntered, zoneId: 'z1'}` | Stream emite `GeofenceEntered('z1')` |
| 15 | Kotlin emite `{type: geofenceExited, zoneId: 'z1'}` | Stream emite `GeofenceExited('z1')` |

### Test exhaustividad de `NativeCommand`

Agregar a `test/platform/bridge/native_command_test.dart`:
- Verificar que el switch sobre los 8 subtipos del sealed class es exhaustivo (sin `default`)

---

## T8 — Tests E2E en dispositivo físico (con `USE_LEGACY_BRIDGE = false`)

Ejecutar con `flutter run` en dispositivo físico, flag false activo.

| Flow | Pasos | Criterio |
|------|-------|---------|
| F1 — Normal→Silent→Normal | Activar MS desde app → app se cierra → abrir app → volver a Normal | MS activo visible en barra, sin regresión al reabrir |
| F2 — BN durante Silent | Con Silent activo, abrir modal barra → seleccionar estado → verificar en Firestore | Estado llega a Firestore; app sigue en Silent tras cerrar modal |
| F3 — SOS con GPS | Enviar SOS desde UI → verificar coordenadas en Firestore | Lat/Lng presentes en documento |
| F4 — Estado manual vía QuickAction | Seleccionar estado desde notificación → verificar sincronización | Estado llega a Flutter y Firestore |
| F5 — Login / Logout | Login → navegar app → Logout → re-login | Sin MissingPluginException en ningún paso |

---

## T9 — Cierre de semana

### Tag `refactor-sem3-done`

```bash
git tag refactor-sem3-done
git push origin refactor-sem3-done
```

### Memoria de cierre `memory/project_refactor_sem3_done.md`

Incluir:
- PR mergeados de Sem 3 (#163–#168 + este)
- Estado de cada handler en BridgeRouter (7/7 activos)
- Callers legacy pendientes de migración (Sem 4+)
- Líneas de `MainActivity.kt` post-flip
- Próximo paso: PR de cleanup legacy (≤300 líneas)

### Borrador `docs/dev/refactor-arch-2026-q2/04-semana-4-identity-circle.md`

Mínimo 3 secciones:
- Objetivo de Sem 4
- Callers a migrar (NativeStateBridge, StatusModalService, NotificationService)
- Primer handler a migrar

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `android/.../BridgeRouter.kt` | Modificado | `handleGeofencing` + `handleBadge` + `emitGeofenceEvent` + campo `registeredZones` |
| `android/.../MainActivity.kt` | Modificado | `setupBridgeRouter` + `setupRemainingLegacyChannels` + bifurcación en `onResume`/`BroadcastReceiver`/`onNewIntent` |
| `android/app/build.gradle` | Modificado | `USE_LEGACY_BRIDGE = false` |
| `lib/platform/bridge/native_command.dart` | Modificado | Agregar `RegisterZone`, `UnregisterZone`, `SetBadgeCount` |
| `lib/platform/bridge/android_native_bridge.dart` | Modificado | `_handleNativeEvent` geofence events + 3 nuevos casos en `invoke()` |
| `test/platform/bridge/android_native_bridge_test.dart` | Modificado | Tests 11-15 |
| `test/platform/bridge/native_command_test.dart` | Modificado | Test exhaustividad 8 subtipos |
| `docs/dev/refactor-arch-2026-q2/03-semana-3-Dia-5.md` | Nuevo | Este documento |
| `docs/dev/refactor-arch-2026-q2/04-semana-4-identity-circle.md` | Nuevo | Borrador Sem 4 |
| `memory/project_refactor_sem3_done.md` | Nuevo | Memoria de cierre |

**Archivos NO modificados:** `GeofencingService.dart`, `AppBadgeService.dart`,
`NativeStateBridge.dart`, `StatusService.dart`, `native_bridge.dart`, `native_event.dart`

---

## Criterios de done

| # | Criterio | Verificación |
|---|----------|-------------|
| 1 | `handleGeofencing` acepta `registerZone`/`unregisterZone`, `emitGeofenceEvent` compilado | Tests 11-12 |
| 2 | `handleBadge` almacena badge count en SharedPrefs | Test 13 |
| 3 | `_handleNativeEvent` enruta `geofenceEntered`/`geofenceExited` al stream | Tests 14-15 |
| 4 | `setupBridgeRouter` registra todos los canales legacy no migrados | F5 E2E (sin MissingPluginException) |
| 5 | `onResume`/`BroadcastReceiver`/`onNewIntent` bifurcan por `USE_LEGACY_BRIDGE` | F2 + F4 E2E |
| 6 | `USE_LEGACY_BRIDGE = false` en `build.gradle` | `grep USE_LEGACY_BRIDGE build.gradle` |
| 7 | `flutter test` — todos en verde (≥113) | Salida del comando |
| 8 | `flutter analyze` — 0 warnings nuevos vs. baseline (394) | Salida del comando |
| 9 | `flutter build apk --debug` — sin errores Kotlin | Salida del build |
| 10 | 5 flows E2E pasan en device físico con flag false | Verificación manual |
| 11 | Tag `refactor-sem3-done` en remoto | `git tag -l` |
| 12 | `memory/project_refactor_sem3_done.md` escrito y en memoria | Archivo presente |
| 13 | `04-semana-4-identity-circle.md` borrador | Archivo presente |

---

## Nota sobre criterio de líneas de `MainActivity.kt`

El plan maestro indica `≤300 líneas` para Día 5. Con `USE_LEGACY_BRIDGE = false`
**el código de `setupLegacyChannels` queda muerto pero físicamente presente**.
Las 300 líneas se logran solo en el PR siguiente (cleanup legacy), que elimina:
- `setupLegacyChannels()` (~280 líneas)
- El bloque comentado al final del archivo (~183 líneas)

**Ese PR va después de 48h de coexistencia** sin incidentes. El criterio real de Día 5 es:
`MainActivity.kt` no crece más de +50 líneas vs. Día 4 (incorporando `setupRemainingLegacyChannels`
como método extraído).

---

## Riesgos específicos de Día 5

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| Canal legacy no registrado en `setupBridgeRouter` → `MissingPluginException` | Alta | Checklist exhaustivo de T3; F5 E2E lo detecta |
| `onResume` / `BroadcastReceiver` / `onNewIntent` no bifurcan → estado perdido con flag false | Alta | 3 puntos de emisión deben incluir bifurcación; F2 + F4 E2E lo detecta |
| `registeredZones` en BridgeRouter se pierde al rotar pantalla (campo de instancia) | Media | Aceptable en Día 5 — BridgeRouter se re-instancia en `configureFlutterEngine`; el flag protege en producción |
| Geofencing dart (GeofencingService) llama a `zync/native_state` indirectamente | Baja | GeofencingService no usa MethodChannels directamente |
| E2E F3 falla por permisos GPS en device CI/test | Media | Verificar en device físico con GPS activo; no en emulador |

---

## Salida de emergencia

Si cualquier E2E falla con `USE_LEGACY_BRIDGE = false`:

```gradle
// Revertir en build.gradle:
buildConfigField "boolean", "USE_LEGACY_BRIDGE", "true"
```

Documentar en `docs/dev/refactor-arch-2026-q2/blockers.md`:
- Flow fallido
- Canal o comportamiento roto
- Canal específico no cubierto (si aplica)

**Sem 4 NO inicia hasta que Sem 3 esté cerrada con flag en false.**

---

**Post-merge: PR de cleanup legacy** — eliminar `setupLegacyChannels()`, código comentado,
imports huérfanos. `MainActivity.kt` queda en ≤300 líneas. Este PR va 48h después del flip.
