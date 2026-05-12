# Sem 3 - Día 2 — Migrar `zync/keep_alive` (Silent Mode) al `BridgeRouter`

**Rama:** `refactor/sem3-bridge-silent`

**PR:** `refactor(bridge): Sem3 Día2 — migrate nunakin/silent to BridgeRouter`

**Fecha planificada:** 2026-05-12 (martes)

**Base:** Día 1 — scaffold del bridge (`refactor/sem3-bridge-scaffold` mergeado)

---

## Objetivo

Migrar el primero de los 7 MethodChannels heredados al nuevo bridge unificado
`nunakin/bridge`:

- **Antes:** `Flutter (MethodChannel('zync/keep_alive'))` ↔ `MainActivity.setupLegacyChannels`
- **Después:** `Flutter (NativeBridge.invoke(ActivateSilentMode))` ↔ `BridgeRouter.handleSilentMode`

El flag `USE_LEGACY_BRIDGE` permanece `true` — la ruta nueva queda dormida hasta que las
5 migraciones de Sem 3 estén verificadas. Mientras tanto:

- El canal `zync/keep_alive` original sigue intacto en `setupLegacyChannels` (no se
  toca para no romper la ruta de producción).
- El canal `nunakin/bridge` con el handler de Silent Mode queda **registrado pero
  inactivo** (solo se conecta cuando el flag pase a `false`).
- `SilentFunctionalityCoordinator` deja de hablar al MethodChannel directo y pasa a
  invocar `NativeBridge` desde DI. El cambio es transparente porque el bridge
  apuntará al canal correcto según el flag (Día 6+ — toggle).

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `android/.../BridgeRouter.kt` | Modificado | Implementa `handleSilentMode` + agrega campo `isSilentModeActive` + recibe `Activity` |
| `android/.../MainActivity.kt` | Modificado | Completa `setupBridgeRouter` (registra `nunakin/bridge`). `setupLegacyChannels` intacto. |
| `lib/platform/bridge/android_native_bridge.dart` | Modificado | Implementa `invoke` para `ActivateSilentMode` / `DeactivateSilentMode`; canal `nunakin/bridge` |
| `lib/core/services/silent_functionality_coordinator.dart` | Modificado | Elimina `MethodChannel` directo; usa `sl<NativeBridge>().invoke(...)` + use cases `EnterSilentMode`/`ExitSilentMode` |
| `test/platform/bridge/android_native_bridge_test.dart` | Nuevo | Tests del invoke con mock channel |
| `docs/dev/refactor-arch-2026-q2/03-semana-3-Dia-2.md` | Nuevo | Este documento |

**Archivos de producción activa no modificados:** todo el resto del canal
`zync/keep_alive` en `setupLegacyChannels`, `KeepAliveService`, `EmojiDialogActivity`,
notificaciones, badge service.

---

## Tarea 1 — `BridgeRouter.handleSilentMode` (Kotlin)

Implementación que replica byte-a-byte la lógica del canal `zync/keep_alive` en
`MainActivity.setupLegacyChannels`. Cambios estructurales mínimos:

| Punto | Decisión |
|-------|----------|
| Constructor | `BridgeRouter(activity: Activity)` — se necesita `Activity` para llamar `finishAndRemoveTask()` y `startActivity(batteryIntent)` |
| Campo de estado | `var isSilentModeActive: Boolean = false` — copia local del router. Mientras `USE_LEGACY_BRIDGE=true`, la fuente real sigue siendo el campo homónimo de `MainActivity`. |
| Métodos del canal | `activateSilentMode`, `deactivateSilentMode`, `checkBattery`, `requestBattery` |

**Importante:** NO se elimina ni se modifica el handler `zync/keep_alive` en
`setupLegacyChannels`. Cuando `USE_LEGACY_BRIDGE` pase a `false`, el router toma el
control; hasta entonces el campo `isSilentModeActive` del router queda en `false` y
nunca se consulta.

---

## Tarea 2 — `setupBridgeRouter` en `MainActivity.kt`

Completa el stub Día 1 instanciando el router y registrando el canal unificado:

```kotlin
private fun setupBridgeRouter(flutterEngine: FlutterEngine) {
    val router = BridgeRouter(activity = this)
    MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "nunakin/bridge"
    ).setMethodCallHandler { call, result ->
        when (call.method) {
            "activateSilentMode"   -> router.handleSilentMode(call, result)
            "deactivateSilentMode" -> router.handleSilentMode(call, result)
            "checkBattery"         -> router.handleSilentMode(call, result)
            "requestBattery"       -> router.handleSilentMode(call, result)
            else                   -> result.notImplemented()
        }
    }
}
```

Solo conecta los 4 métodos de Silent Mode. Los handlers Día 3-5 quedan en
`result.notImplemented()` y se cablearán en las migraciones siguientes.

---

## Tarea 3 — `AndroidNativeBridge.invoke` (Dart)

Implementación tipada de los dos primeros comandos en `nunakin/bridge`:

```dart
@override
Future<T> invoke<T>(NativeCommand<T> cmd) async {
  switch (cmd) {
    case ActivateSilentMode():
      await _channel.invokeMethod<void>('activateSilentMode');
      return null as T;
    case DeactivateSilentMode():
      await _channel.invokeMethod<void>('deactivateSilentMode');
      return null as T;
    default:
      throw UnimplementedError('AndroidNativeBridge.invoke: $cmd');
  }
}
```

El channel ahora es inyectable (parámetro opcional del constructor) para que los
tests puedan mockearlo. La constante `channelName = 'nunakin/bridge'` queda anotada
con `@visibleForTesting`.

---

## Tarea 4 — `SilentFunctionalityCoordinator` usa `NativeBridge`

Eliminaciones:

- Campo estático `_channel = MethodChannel('zync/keep_alive')` → removido.
- Import de `package:flutter/services.dart` → removido.

Reemplazos:

| Antes | Después |
|-------|---------|
| `await _channel.invokeMethod('activate')` | `await sl<NativeBridge>().invoke(const ActivateSilentMode())` |
| `await _channel.invokeMethod('deactivate')` | `await sl<NativeBridge>().invoke(const DeactivateSilentMode())` |

Añadidos antes de invocar el nativo:

- `activateSilentMode` → `await sl<EnterSilentMode>().call(userId: user.uid)` si hay
  `FirebaseAuth.currentUser`.
- `deactivateAfterLogout` → `await sl<ExitSilentMode>().call(userId: user.uid)` si hay
  `FirebaseAuth.currentUser`.

**Doble escritura de SharedPrefs — documentado en código:** el use case
`EnterSilentMode` escribe en `SharedPrefsPresenceRepository` (namespace
`flutter.*`). El `Coordinator` también escribe `is_silent_mode_active` y
`pre_silent_status_id` en Flutter SharedPreferences, y el canal Kotlin escribe en
`zync_silent_mode` (namespace nativo). Son namespaces distintos: no hay conflicto,
pero queda comentado para que ninguna sesión futura confunda responsabilidades.

---

## Tarea 5 — Tests Dart

`test/platform/bridge/android_native_bridge_test.dart` — 4 tests:

| # | Escenario | Verifica |
|---|-----------|----------|
| 1 | `invoke(ActivateSilentMode())` | El canal recibe `activateSilentMode` sin args |
| 2 | `invoke(DeactivateSilentMode())` | El canal recibe `deactivateSilentMode` sin args |
| 3 | `invoke(GetCurrentLocation())` | Lanza `UnimplementedError` y no toca el canal |
| 4 | `channelName == 'nunakin/bridge'` | El nombre del canal está fijo |

Se usa `TestDefaultBinaryMessengerBinding.setMockMethodCallHandler` para capturar las
llamadas. El channel se inyecta vía constructor para que el mock funcione.

---

## Verificaciones de done

| Criterio | Resultado |
|----------|-----------|
| `flutter analyze` — 0 warnings nuevos vs baseline (394) | ✅ 394 issues, 0 nuevos |
| `flutter test test/platform/bridge/` — todos en verde | ✅ 16/16 |
| `flutter test` suite completa | ✅ 103 ✅ / 1 skip preexistente |
| `flutter build apk --debug` — Kotlin compila sin warnings nuevos | ✅ build OK |
| `MainActivity.kt` no perdió código del canal `zync/keep_alive` | ✅ intacto |
| `USE_LEGACY_BRIDGE` sigue `true` | ✅ ruta de producción no cambió |

---

## Riesgos y mitigación

| Riesgo | Mitigación |
|--------|-----------|
| Doble path activo de Silent Mode (legacy + bridge) si el flag cambia a `false` | El flag se mantiene en `true` hasta cierre de Sem 3. El handler de bridge queda registrado pero nadie le habla todavía. |
| `EnterSilentMode` use case falla y bloquea la activación nativa | Se envuelve en try/catch — fallo del use case se loguea pero la activación nativa procede igual. |
| Doble escritura `SharedPreferences` (use case + escritura directa) | Documentado en comentarios de código. No hay conflicto: namespaces distintos. |
| `Activity` en lugar de `Context` en `BridgeRouter` expone APIs peligrosas | Aceptable: el router ya es código de Activity (registra MethodChannels). Encapsulado en `private val activity`. |

---

## Estado al cierre

- `BridgeRouter.handleSilentMode` implementado y validado por build Android.
- `AndroidNativeBridge.invoke` cubre `ActivateSilentMode` y `DeactivateSilentMode`.
- `SilentFunctionalityCoordinator` ya no menciona `MethodChannel` — solo el bridge.
- Tests del bridge: 16/16 ✅.
- Suite completa: 103 ✅ / 1 skip.
- `MainActivity.kt`: 1019 líneas (vs 1007 baseline — +12 por el cuerpo de
  `setupBridgeRouter`). La reducción real ocurrirá en Día 6+ cuando se elimine el
  handler legacy.

---

**Siguiente: Día 3 — Migrar `zync/status_update` (Worker) y `zync/sos` al BridgeRouter**
