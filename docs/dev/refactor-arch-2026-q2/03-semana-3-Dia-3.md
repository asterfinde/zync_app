# Sem 3 - Día 3 — Migrar eventos de status/SOS (Kotlin → Flutter)

**Rama:** `refactor/sem3-bridge-status-sos`

**Modelo de implementación:** **Claude Opus 4.7** — obligatorio. La bidireccionalidad del
canal (Kotlin→Flutter para eventos + Flutter→use cases), el Worker en background y los
3 puntos de emisión hacen que este día sea de igual riesgo que Día 2.

**Fecha planificada:** 2026-05-21 (miércoles)

**Base:** rama `main` post-PR #163 → commit `a0cf817`

---

## Contexto y hallazgo crítico

> **Día 3 es cualitativamente distinto de Día 2.**

En Día 2 se migró un canal existente con dirección **Flutter→Kotlin** (`activate`/`deactivate`
en `zync/keep_alive`). En Día 3 la dirección dominante es **Kotlin→Flutter**: el código Kotlin
emite eventos hacia Flutter cuando el usuario selecciona un estado desde la barra de
notificaciones, un QuickAction, o EmojiDialogActivity.

### Lo que existe hoy

| Punto de emisión | Canal actual | Dirección | Método |
|------------------|-------------|-----------|--------|
| `BroadcastReceiver` (L70) — QuickAction | `com.datainfers.zync/status_update` | Kotlin → Flutter | `updateStatus` |
| `onResume()` (L280) — pending_status cache | `com.datainfers.zync/status_update` | Kotlin → Flutter | `updateStatus` |
| `onNewIntent()` (L341) — EmojiDialogActivity | `com.datainfers.zync/status_update` | Kotlin → Flutter | `updateStatus` |
| `StatusUpdateWorker.doWork()` | SharedPrefs directas — **sin MethodChannel** | Worker → SharedPrefs → onResume | — |

### Lo que NO existe

- Canal `nunakin/status` → **hay que crearlo** como ruta nueva dentro de `nunakin/bridge`
- Canal `nunakin/sos` → **hay que crearlo** (SOS desde Flutter va directo a Firestore; el
  Worker lo maneja vía inputData con GPS ya capturado en foreground)

### Flujo SOS (dos caminos)

```
SOS desde UI Flutter:
  StatusService.updateUserStatus(SOS) → GPSService → Firestore (batch) → SharedPrefs

SOS desde barra nativa (EmojiDialogActivity):
  EmojiDialogActivity (GPS foreground) → WorkManager inputData →
  StatusUpdateWorker.doWork() → Firestore directo →
  SharedPrefs pending_status → onResume() → canal → Flutter
```

El `StatusUpdateWorker` **no puede usar MethodChannel** (background worker sin acceso al
FlutterEngine). Este riesgo está identificado en el plan maestro — la solución es mantener
el camino SharedPrefs→onResume pero redirigirlo al canal unificado.

---

## Inventario de cambios

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `android/.../BridgeRouter.kt` | Modificado | Implementar `emitStatusEvent()` + `handleStatus()` + `handleSOS()` |
| `android/.../MainActivity.kt` | Modificado | Los 3 puntos de emisión usan `BridgeRouter.emitStatusEvent()` |
| `lib/platform/bridge/android_native_bridge.dart` | Modificado | `initialize(BinaryMessenger)` para recibir eventos Kotlin→Flutter |
| `lib/core/services/status_service.dart` | Modificado | Agregar llamada a `SetManualStatus` + `RaiseSOS` use cases |
| `test/platform/bridge/android_native_bridge_test.dart` | Modificado | Tests para event channel (Kotlin→Dart) |
| `docs/dev/refactor-arch-2026-q2/03-semana-3-Dia-3.md` | Nuevo | Este documento |

**Archivos no modificados:** `native_bridge.dart`, `native_event.dart`,
`native_command.dart`, `platform_module.dart`, `StatusUpdateWorker.kt`,
`EmojiDialogActivity.kt`, `in_circle_view.dart`.

---

## Restricciones explícitas — lo que NO se hace en Día 3

> Estas restricciones son tan importantes como las tareas. Opus debe leerlas antes de
> tocar cualquier archivo.

| Restricción | Razón |
|-------------|-------|
| **NO tocar `StatusUpdateWorker.kt`** | El Worker corre en background sin FlutterEngine — no puede usar MethodChannel. La migración completa al bridge es Día 5. |
| **NO llamar `SetManualStatus.call()` completo** | `SetManualStatus` llama a `_publisher.publish()` que escribe a Firestore. `StatusService` ya hace un batch write. Doble escritura → datos corruptos. Usar `repo.saveState()` directo (solo SharedPrefs, sin publisher). |
| **NO modificar los 3 puntos de emisión legacy** (`BroadcastReceiver`, `onResume`, `onNewIntent`) | Están en la ruta `setupLegacyChannels` que permanece intacta mientras `USE_LEGACY_BRIDGE = true`. Solo agregar equivalentes en `setupBridgeRouter`. |
| **NO eliminar `com.datainfers.zync/status_update`** | Canal legacy activo en producción. Se elimina en Día 5 tras el flip del flag. |
| **NO hacer `USE_LEGACY_BRIDGE = false`** | El flag se flipea solo al cierre de Día 5, cuando todos los handlers están implementados y validados en device. |

---

## Tareas

---

### T1 — `BridgeRouter.emitStatusEvent()` (Kotlin)

Agregar un método que centraliza la emisión del evento `StatusUpdatedFromNotification`:

```kotlin
/**
 * Emite un evento de estado actualizado hacia Flutter.
 *
 * En legacy path: usa el canal legacy (llamado desde MainActivity directamente).
 * En bridge path: usa nunakin/bridge para que AndroidNativeBridge lo enrute al
 *   stream de eventos Dart.
 *
 * La distinción legacy/bridge la hace el caller (MainActivity), no este método.
 */
fun emitStatusEvent(messenger: BinaryMessenger, statusId: String) {
    val channel = MethodChannel(messenger, "nunakin/bridge")
    channel.invokeMethod(
        "nativeEvent",
        mapOf("type" to "statusUpdated", "statusId" to statusId)
    )
}
```

Adicionalmente, implementar `handleStatus` para el caso Flutter→Kotlin (por completitud del
stub — no se usa en producción mientras `USE_LEGACY_BRIDGE = true`):

```kotlin
override fun handleStatus(call: MethodCall, result: MethodChannel.Result) {
    // Flutter→Kotlin: usado cuando Flutter notifica al bridge un cambio de estado
    // para que Kotlin pueda actualizar la notificación persistente.
    // Día 3: registrar el método — la implementación real (actualizar notif) es Día 4.
    result.notImplemented()
}

override fun handleSOS(call: MethodCall, result: MethodChannel.Result) {
    // Flutter→Kotlin: SOS desde UI Flutter.
    // Día 3: stub. La lógica real de GPS y Worker se migra en Día 4.
    result.notImplemented()
}
```

**Invariante:** `setupLegacyChannels` **no se toca**. Los 3 puntos de llamada legacy siguen
usando `com.datainfers.zync/status_update` sin cambios.

---

### T2 — `MainActivity.kt` — 3 puntos de emisión apuntan al BridgeRouter (path nueva)

En `setupBridgeRouter()`, instanciar el router y agregar los 3 caminos de emisión en el path
del nuevo bridge. **El código legacy en `setupLegacyChannels` permanece intacto.**

Estructura en `setupBridgeRouter`:

```kotlin
private fun setupBridgeRouter(flutterEngine: FlutterEngine) {
    val router = BridgeRouter(activity = this)
    val messenger = flutterEngine.dartExecutor.binaryMessenger

    MethodChannel(messenger, "nunakin/bridge").setMethodCallHandler { call, result ->
        when (call.method) {
            // Silent (Día 2)
            "activateSilentMode"   -> router.handleSilentMode(call, result)
            "deactivateSilentMode" -> router.handleSilentMode(call, result)
            "checkBattery"         -> router.handleSilentMode(call, result)
            "requestBattery"       -> router.handleSilentMode(call, result)
            // Status / SOS (Día 3 — stubs por ahora)
            "updateStatus"         -> router.handleStatus(call, result)
            "raiseSOS"             -> router.handleSOS(call, result)
            else                   -> result.notImplemented()
        }
    }

    // Reemplazar los 3 puntos de emisión legacy — solo activo cuando flag = false
    // (1) BroadcastReceiver — ya registrado en onCreate(); accede via router
    // (2) onResume() — llamar router.emitStatusEvent(messenger, pendingStatus)
    //     en vez de com.datainfers.zync/status_update.invokeMethod(...)
    // (3) onNewIntent() — ídem
}
```

**Nota de implementación para Opus:** Los 3 puntos de emisión están en `onCreate`
(BroadcastReceiver), `onResume` y `onNewIntent` — todos fuera de `configureFlutterEngine`.
La referencia al messenger solo está disponible cuando el FlutterEngine está listo.
La solución más limpia es guardar el `messenger` en un campo de la Activity al entrar en
`setupBridgeRouter`, igual que se hace en el código legacy con el `flutterEngine` field.

---

### T3 — `AndroidNativeBridge.initialize(BinaryMessenger)` (Dart)

Agregar un método de inicialización que registra el handler para los eventos entrantes
de Kotlin. Este es el lado Dart del canal de eventos Kotlin→Flutter.

```dart
static const _channel = MethodChannel('nunakin/bridge');

/// Registra el handler para eventos entrantes desde el lado nativo.
///
/// Debe llamarse una vez, cuando el FlutterEngine esté listo.
/// En producción se llama desde [platform_module.dart] o desde main().
/// Mientras USE_LEGACY_BRIDGE = true, este método se puede llamar sin efecto.
void initialize() {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'nativeEvent') {
      _handleNativeEvent(call.arguments as Map<dynamic, dynamic>);
    }
  });
}

void _handleNativeEvent(Map<dynamic, dynamic> args) {
  final type = args['type'] as String?;
  switch (type) {
    case 'statusUpdated':
      final statusId = args['statusId'] as String?;
      if (statusId != null) {
        _eventController.add(StatusUpdatedFromNotification(statusId));
      }
    case 'silentDeactivated':
      _eventController.add(const SilentDeactivatedByUser());
    case 'sessionCleared':
      _eventController.add(const SessionCleared());
    default:
      // Evento desconocido — ignorar silenciosamente
      break;
  }
}
```

**Punto de llamada:** `platform_module.dart` debe llamar `initialize()` después de registrar
el singleton. Verificar que el `BinaryMessenger` esté disponible en ese punto del lifecycle
(puede requerir pasar el messenger explícitamente o diferir la llamada).

---

### T4 — `StatusService.updateUserStatus` agrega use cases (Dart)

**Riesgo crítico: doble escritura a Firestore.**

`SetManualStatus` llama a `_publisher.publish()` que escribe a Firestore. `StatusService`
también escribe via batch. Si se llaman ambos, habrá doble escritura. La estrategia para
Día 3 es:

**Opción elegida — state sync solamente (sin publisher.publish):**

Agregar llamada a `_repository.saveState()` directamente (no a `SetManualStatus` completo)
para sincronizar el estado en `SharedPrefsPresenceRepository` sin triggear el publisher:

```dart
// Al final de updateUserStatus(), DESPUÉS del batch.commit() exitoso:
// Sync de estado en PresenceRepository (sin publicar a Firestore — ya publicado via batch)
try {
  final repo = sl<PresenceRepository>();
  await repo.saveState(Normal(
    currentId:    newStatus.id,
    lastManualId: newStatus.id,
  ));
  log('[StatusService] ✅ PresenceRepository sincronizado: ${newStatus.id}');
} catch (e) {
  log('[StatusService] ⚠️ Error sync PresenceRepository: $e');
}
```

Para SOS, llamar `sl<RaiseSOS>()` con las coordenadas capturadas:

```dart
if (newStatus.id == StatusIds.sos && coordinates != null) {
  try {
    await sl<RaiseSOS>().call(
      userId:    user.uid,
      circleId:  circleId,
      latitude:  coordinates.latitude,
      longitude: coordinates.longitude,
    );
    log('[StatusService] ✅ RaiseSOS use case ejecutado');
  } catch (e) {
    log('[StatusService] ⚠️ RaiseSOS use case error (no crítico): $e');
  }
}
```

**Marcado como `@Deprecated`:** Agregar anotación al método para señalizar que la ruta
futura es `SetManualStatus` / `RaiseSOS` directamente, sin pasar por `StatusService`.

**Invariante:** el batch.commit() y toda la lógica de zonas/GPS previa NO se modifica.
Solo se agregan los calls a los use cases al final, después del commit exitoso.

---

### T5 — Tests unitarios

Extender `test/platform/bridge/android_native_bridge_test.dart`:

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 5 | `initialize()` + Kotlin emite `{type: statusUpdated, statusId: fine}` | `events` stream emite `StatusUpdatedFromNotification('fine')` |
| 6 | Kotlin emite `{type: silentDeactivated}` | `events` stream emite `SilentDeactivatedByUser()` |
| 7 | Kotlin emite tipo desconocido `{type: unknown}` | stream **no** emite nada (no lanza) |

---

## Criterios de done

| # | Criterio | Verificación |
|---|----------|-------------|
| 1 | Los 3 puntos de emisión legacy (`com.datainfers.zync/status_update`) están **intactos** | `grep -n "status_update" MainActivity.kt` — debe mostrar 3 resultados |
| 2 | `BridgeRouter.emitStatusEvent()` implementado | Code review |
| 3 | `AndroidNativeBridge.initialize()` registra handler para `nativeEvent` | Tests 5-7 en verde |
| 4 | `StatusService.updateUserStatus` llama `repo.saveState()` y `RaiseSOS` tras commit | Code review + test log |
| 5 | `flutter test` — todos en verde (≥103) | Salida del comando |
| 6 | `flutter analyze` — 0 warnings nuevos vs. baseline (394) | Salida del comando |
| 7 | `flutter build apk --debug` — sin errores Kotlin | Salida del build |
| 8 | `MainActivity.kt` no crece más de 10 líneas | `wc -l MainActivity.kt` ≤ 1029 |

---

## Riesgos específicos del Día 3

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| Doble escritura Firestore si se llama `SetManualStatus.call()` completo | Alta | Usar `repo.saveState()` directo, sin publisher (ver T4) |
| `messenger` no disponible en `platform_module.dart` al llamar `initialize()` | Media | Diferir la llamada a cuando el FlutterEngine esté listo; evaluar MethodChannel.setMethodCallHandler en `main()` |
| `StatusUpdateWorker` no puede emitir via bridge (background sin FlutterEngine) | Alta | Worker sigue escribiendo SharedPrefs; `onResume()` recoge y emite el evento — sin cambio de comportamiento |
| `RaiseSOS` use case re-escribe Firestore con estado simplificado (sin zonas) | Media | Llamar `RaiseSOS` DESPUÉS del batch.commit() exitoso — el Worker tiene el dato más reciente en Firestore |

---

## Nota sobre `StatusUpdateWorker`

El Worker **no cambia en Día 3**. La ruta Worker→SharedPrefs→onResume→Flutter permanece
intacta. Lo que cambia en Día 3 es que `onResume()` (en la ruta nueva con `USE_LEGACY_BRIDGE=false`)
usa `BridgeRouter.emitStatusEvent()` en lugar de construir un `MethodChannel` ad-hoc.
Con el flag en `true`, `onResume()` sigue igual.

La migración completa del Worker al bridge (emitir eventos sin SharedPrefs) es trabajo de
Día 5 (cierre de semana) cuando todas las piezas estén conectadas.

---

## Línea de criterio de MainActivity.kt

| Día | Meta de líneas | Estado |
|-----|---------------|--------|
| Inicio Sem 3 | 1007 | baseline |
| Post Día 2 | 1019 | +12 (setupBridgeRouter completado) |
| Post Día 3 | ≤ 1029 | +10 máx (ajustes en setupBridgeRouter) |
| Post Día 5 | ≤ 300 | meta final (legacy eliminado) |

---

**Siguiente: Día 4 — Migrar `nunakin/location` + `nunakin/session`**
(`GetCurrentLocation` command + `SetUserSession`/`ClearSession` commands)
