# Semana 3 — Native Bridge (semana crítica)

> **Período:** lunes 2026-05-19 a viernes 2026-05-23 (5 días hábiles)
> **Riesgo global:** ALTO — semana crítica. Usar **Opus** para toda la implementación.
> **Premisa:** feature flag `USE_LEGACY_BRIDGE` activo durante toda la semana. Los 7
> MethodChannels viejos coexisten 48h post-merge antes de eliminarse.
> **Documento padre:** [00-plan-unificado.md](00-plan-unificado.md).

---

## 0. Objetivo

Reemplazar los 7 MethodChannels heterogéneos por **un único canal `nunakin/bridge` v1**
con protocolo sealed. Al cierre de la semana:

- `MainActivity.kt` baja de 996 a ≤300 líneas.
- `SilentFunctionalityCoordinator.activateSilentMode` llama a `EnterSilentMode` use case
  + `NativeBridge.invoke(ActivateSilentMode())`.
- `StatusUpdateWorker` ya no escribe `flutter.current_status_id` directamente — emite
  evento por bridge.
- `StatusService.updateUserStatus` envuelve a `SetManualStatus` (wrapper deprecated).

**El comportamiento observable de la app es idéntico al baseline en todo momento.**

---

## 1. Premisas y reglas de la semana

1. **Feature flag primero.** Antes de tocar un solo MethodChannel, el flag
   `USE_LEGACY_BRIDGE` debe estar funcional en `build.gradle`.
2. **Un canal a la vez.** Migrar un handler, verificar en device físico, luego el
   siguiente. Nunca migrar dos handlers en el mismo commit si generan acoplamiento.
3. **`main` siempre verde.** Si un test E2E falla → revertir inmediatamente, no parchar.
4. **`MainActivity.kt` no crece.** Cada handler migrado a `BridgeRouter` reduce líneas en
   `MainActivity`. Si el conteo no baja → algo está mal.
5. **Tests E2E en device físico al cierre de cada día.** No al cierre de la semana.

---

## 2. Inventario de MethodChannels a migrar

| Canal actual | Handler | Destino en BridgeRouter |
|--------------|---------|-------------------------|
| `nunakin/silent` | `activateSilentMode` / `deactivateSilentMode` | `SilentModeHandler` |
| `nunakin/status` | `updateStatus` | `StatusHandler` |
| `nunakin/sos` | `raiseSOS` | `SOSHandler` |
| `nunakin/location` | `getCurrentLocation` | `LocationHandler` |
| `nunakin/session` | `setUserSession` / `clearSession` | `SessionHandler` |
| `nunakin/geofencing` | `registerZone` / `unregisterZone` | `GeofencingHandler` |
| `nunakin/badge` | `setBadgeCount` | `BadgeHandler` |

---

## 3. Plan día por día

---

### Día 1 (lunes) — Scaffold del bridge + feature flag

**Rama:** `refactor/sem3-bridge-scaffold`

**Tareas:**

#### 1. Feature flag en `build.gradle`

```gradle
// android/app/build.gradle
buildConfigField "boolean", "USE_LEGACY_BRIDGE", "true"
```

Leer en `MainActivity.kt`:

```kotlin
if (BuildConfig.USE_LEGACY_BRIDGE) {
    setupLegacyChannels()
} else {
    setupBridgeRouter()
}
```

#### 2. `lib/platform/bridge/native_bridge.dart`

```dart
import 'package:nunakin_app/platform/bridge/native_command.dart';
import 'package:nunakin_app/platform/bridge/native_event.dart';

abstract class NativeBridge {
  Stream<NativeEvent> get events;
  Future<T> invoke<T>(NativeCommand<T> cmd);
}
```

#### 3. `lib/platform/bridge/native_event.dart`

```dart
sealed class NativeEvent { const NativeEvent(); }

class StatusUpdatedFromNotification extends NativeEvent {
  final String statusId;
  const StatusUpdatedFromNotification(this.statusId);
}

class SilentDeactivatedByUser extends NativeEvent { const SilentDeactivatedByUser(); }
class GeofenceEntered extends NativeEvent {
  final String zoneId;
  const GeofenceEntered(this.zoneId);
}
class GeofenceExited extends NativeEvent {
  final String zoneId;
  const GeofenceExited(this.zoneId);
}
class SessionCleared extends NativeEvent { const SessionCleared(); }
```

#### 4. `lib/platform/bridge/native_command.dart`

```dart
sealed class NativeCommand<T> { const NativeCommand(); }

class ActivateSilentMode extends NativeCommand<void> { const ActivateSilentMode(); }
class DeactivateSilentMode extends NativeCommand<void> { const DeactivateSilentMode(); }
class GetCurrentLocation extends NativeCommand<({double lat, double lng})> {
  const GetCurrentLocation();
}
class SetUserSession extends NativeCommand<void> {
  final String uid;
  final String email;
  const SetUserSession({required this.uid, required this.email});
}
class ClearSession extends NativeCommand<void> { const ClearSession(); }
```

#### 5. `lib/platform/bridge/android_native_bridge.dart` — stub

Implementación mínima que falla con `UnimplementedError` (se completa en Día 2-3).

#### 6. `android/.../BridgeRouter.kt` — clase vacía con los 7 handler stubs

```kotlin
class BridgeRouter(private val context: Context) {
    fun handleSilentMode(call: MethodCall, result: MethodChannel.Result) { /* Día 2 */ }
    fun handleStatus(call: MethodCall, result: MethodChannel.Result)     { /* Día 3 */ }
    fun handleSOS(call: MethodCall, result: MethodChannel.Result)        { /* Día 3 */ }
    fun handleLocation(call: MethodCall, result: MethodChannel.Result)   { /* Día 4 */ }
    fun handleSession(call: MethodCall, result: MethodChannel.Result)    { /* Día 4 */ }
    fun handleGeofencing(call: MethodCall, result: MethodChannel.Result) { /* Día 5 */ }
    fun handleBadge(call: MethodCall, result: MethodChannel.Result)      { /* Día 5 */ }
}
```

**Entregable:** PR `refactor(bridge): scaffold NativeBridge + BridgeRouter + feature flag`

---

### Día 2 (martes) — Migrar `nunakin/silent`

**Rama:** `refactor/sem3-bridge-silent`

**Tareas:**

1. Completar `BridgeRouter.handleSilentMode` extrayendo lógica de `MainActivity.kt`.
2. `AndroidNativeBridge.invoke(ActivateSilentMode)` → `BridgeRouter.handleSilentMode`.
3. `SilentFunctionalityCoordinator.activateSilentMode` → llama a
   `EnterSilentMode` use case + `NativeBridge.invoke(ActivateSilentMode())`.
4. `SilentFunctionalityCoordinator.deactivateSilentMode` → `ExitSilentMode` use case.
5. Tests unitarios en Kotlin: `BridgeRouterSilentTest`.
6. Test E2E en device físico: ciclo Silent Mode completo (activar → backgrounding → desactivar).

**Criterio:** `MainActivity.kt` ≤750 líneas (baja ≥246 líneas vs. 996).

---

### Día 3 (miércoles) — Migrar `nunakin/status` + `nunakin/sos`

**Rama:** `refactor/sem3-bridge-status-sos`

**Tareas:**

1. `BridgeRouter.handleStatus` — extrae de `MainActivity`.
2. `StatusService.updateUserStatus` → wrapper deprecated que llama a `SetManualStatus`.
3. `StatusUpdateWorker` (Kotlin) ya no escribe `flutter.current_status_id` directamente
   — emite evento `StatusUpdatedFromNotification` por el canal unificado.
4. `BridgeRouter.handleSOS` — extrae de `MainActivity`.
5. Test E2E: seleccionar estado manual, verificar que llega a Firestore.

**Criterio:** `MainActivity.kt` ≤500 líneas.

---

### Día 4 (jueves) — Migrar `nunakin/location` + `nunakin/session`

**Rama:** `refactor/sem3-bridge-location-session`

**Tareas:**

1. `BridgeRouter.handleLocation` — extrae de `MainActivity`.
2. `AndroidNativeBridge.invoke(GetCurrentLocation)` → `BridgeRouter.handleLocation`.
3. `BridgeRouter.handleSession` — extrae de `MainActivity`.
4. `SessionHandler` emite `SessionCleared` event cuando recibe logout.
5. Test E2E: SOS con GPS real, verificar coordenadas en Firestore.

**Criterio:** `MainActivity.kt` ≤350 líneas.

---

### Día 5 (viernes) — Migrar `nunakin/geofencing` + `nunakin/badge` + cierre

**Rama:** `refactor/sem3-bridge-geo-badge-close`

**Tareas:**

1. `BridgeRouter.handleGeofencing` — extrae de `MainActivity`.
2. Emisión de `GeofenceEntered`/`GeofenceExited` via `AndroidNativeBridge.events`.
3. `BridgeRouter.handleBadge` — extrae de `MainActivity`.
4. `AndroidNativeBridge` implementación completa — los 7 handlers activos.
5. Flip del feature flag: `USE_LEGACY_BRIDGE = false`.
6. 48h de coexistencia → eliminar handlers viejos de `MainActivity` en siguiente PR.
7. `flutter test` — todos en verde.
8. `flutter analyze` — 0 warnings nuevos vs. baseline.
9. Tests E2E completos: ciclo Normal→Silent→Normal, BN durante Silent, SOS desde notif.
10. Tag `refactor-sem3-done`.
11. Memoria de cierre `project_refactor_sem3_done.md`.
12. Borrador `04-semana-4-identity-circle.md`.

**Criterio:** `MainActivity.kt` ≤300 líneas (meta del plan).

---

## 4. Estructura de archivos resultante (al cierre de Sem 3)

```
lib/
├── platform/
│   └── bridge/
│       ├── native_bridge.dart          ← interfaz
│       ├── native_event.dart           ← sealed events
│       ├── native_command.dart         ← sealed commands
│       └── android_native_bridge.dart  ← impl Android
│
└── contexts/
    └── presence/
        └── application/
            └── use_cases/
                ├── enter_silent_mode.dart  ← ahora invocado desde SilentCoordinator
                └── exit_silent_mode.dart   ← ídem

android/app/src/main/kotlin/com/datainfers/zync/
├── MainActivity.kt       ← ≤300 líneas
├── BridgeRouter.kt       ← handlers extraídos (~400 líneas)
├── SilentModeHandler.kt  ← opcional (si BridgeRouter supera 300 líneas)
└── StatusUpdateWorker.kt ← emite via bridge en vez de escribir prefs directo
```

---

## 5. Riesgos específicos de Sem 3

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| MethodChannel renaming rompe llamadas desde Flutter | Alta | Mantener nombres de canal en `SharedKeys.kt` y `native_bridge.dart` sincronizados |
| `StatusUpdateWorker` (background) no tiene acceso al bridge | Alta | WorkerManager → EventBus via SharedPrefs flag, no MethodChannel directo |
| Lifecycle de `BridgeRouter` — instanciado en `onFlutterEngineAttachedToActivity` | Media | Mismo lifecycle que los canales actuales — no hay cambio de ciclo |
| Feature flag `false` rompe funcionalidad existente | Baja | Tests E2E en device antes de flipear |
| `MainActivity.kt` no baja a ≤300 líneas | Media | Si en Día 4 supera 350, extraer `SilentModeHandler.kt` y `StatusHandler.kt` separados |

---

## 6. Criterios de aceptación (semana completa)

| # | Criterio | Verificación |
|---|----------|-------------|
| 1 | App funciona idéntico al baseline | Tests E2E en device físico |
| 2 | `MainActivity.kt` ≤300 líneas | `wc -l MainActivity.kt` |
| 3 | 7 MethodChannels → 1 canal `nunakin/bridge` | `grep -r "MethodChannel" android/` |
| 4 | `flutter test` en verde | Salida del comando |
| 5 | `flutter analyze` 0 warnings nuevos | Comparar vs. baseline 394 |
| 6 | `SilentFunctionalityCoordinator` llama a `EnterSilentMode` use case | Code review |
| 7 | `StatusUpdateWorker` no escribe SharedPrefs directamente | Code review |
| 8 | Feature flag en `false` (bridge nuevo activo) | `BuildConfig.USE_LEGACY_BRIDGE == false` |
| 9 | Tag `refactor-sem3-done` en remoto | `git tag -l` |
| 10 | Memoria de cierre publicada | Archivo en `memory/` |
| 11 | Borrador `04-semana-4-identity-circle.md` publicado | Archivo en `docs/dev/` |

---

## 7. Salida de emergencia

Si en cualquier día el comportamiento observable cambia (bug nuevo en producción):

1. `USE_LEGACY_BRIDGE = true` — revertir a canales viejos sin tener que hacer rollback de código.
2. Documentar el bloqueador en `docs/dev/refactor-arch-2026-q2/blockers.md`.
3. **Sem 4 NO inicia** hasta que Sem 3 esté cerrada.
4. Si el bloqueador no se resuelve en 24h, reevaluar scope con el desarrollador.

**Punto de reversión seguro:** tag `refactor-sem2-done` (commit `08d8962`).

---

## 8. Nota sobre modelo de IA

**Usar Opus para toda la semana** — la migración del bridge tiene más interdependencias
que cualquier semana anterior (Flutter↔Kotlin bidireccional, lifecycle de Activity,
background workers). Sonnet puede usarse para tests unitarios aislados pero no para
el diseño de la arquitectura del canal.
