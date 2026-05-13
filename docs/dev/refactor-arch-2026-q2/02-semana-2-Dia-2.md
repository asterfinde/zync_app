# Sem 2 - Día 2 — `PresenceRepository` port + `SharedPrefsPresenceRepository`

**Rama:** `refactor/sem2-presence-repo`

**PR:** `refactor(presence): PresenceRepository port + SharedPrefsPresenceRepository`

**Fecha planificada:** 2026-05-19 (martes)

**Base:** PR #155 → commit `cde91c1`

---

## Contexto

Día 2 de Sem 2. Se construye el puerto `PresenceRepository` y su implementación concreta que lee/escribe las 5 claves de SharedPreferences hoy dispersas entre `StatusService` y `SilentFunctionalityCoordinator`. La impl es nueva — **no modifica los servicios existentes**. El único código de producción que se toca son `native_keys.dart` y `SharedKeys.kt` (agregar `silentEnteredAt`).

**Pre-checks antes de empezar:**

| Check | Estado |
|-------|--------|
| `KvStore` tiene `getInt`/`setInt` | ✅ Confirmado en `lib/platform/persistence/kv_store.dart` |
| `fake_cloud_firestore` en `dev_dependencies` | Verificar en `pubspec.yaml` antes de Día 4 (no bloquea hoy) |

---

## Tarea 1 — Agregar `silentEnteredAt` a `NativeSharedKeys` y `SharedKeys.kt`

### `lib/platform/persistence/native_keys.dart`

Agregar en la sección `// ── Presence`, después de `isSilentModeActive`:

```dart
  /// Timestamp (ms epoch) de cuándo se activó Silent Mode.
  /// Escrito por: EnterSilentMode use case.
  /// Leído por: SharedPrefsPresenceRepository.
  /// Eliminado por: ExitSilentMode use case (y MainActivity al desactivar Silent Mode).
  static const silentEnteredAt = 'silent_entered_at';
```

### `android/app/src/main/kotlin/com/datainfers/zync/SharedKeys.kt`

Agregar en el grupo `// Presence`, después de `IS_SILENT_MODE_ACTIVE`:

```kotlin
    const val SILENT_ENTERED_AT = "silent_entered_at"
```

---

## Tarea 2 — `lib/contexts/presence/application/ports/presence_repository.dart`

```dart
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Puerto de acceso al estado de presencia persistido.
///
/// La impl lee/escribe las 5 claves de SharedPreferences que
/// hoy gestiona StatusService y SilentFunctionalityCoordinator
/// de forma incoherente entre sí.
abstract class PresenceRepository {
  /// Reconstruye el estado actual desde SharedPreferences.
  /// Si no hay datos, devuelve [Normal] con [StatusIds.fine].
  Future<Result<PresenceState>> currentState();

  /// Persiste coherentemente todas las claves necesarias para [state].
  Future<Result<Unit>> saveState(PresenceState state);

  /// Emite cada vez que se llama a [saveState] con éxito.
  /// Solo activo mientras el proceso Flutter esté en foreground.
  Stream<PresenceState> get stateStream;
}
```

---

## Tarea 3 — `lib/contexts/presence/infrastructure/shared_prefs_presence_repository.dart`

```dart
import 'dart:async';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';
import 'package:nunakin_app/platform/persistence/native_keys.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class SharedPrefsPresenceRepository implements PresenceRepository {
  final KvStore _kv;
  final _stateController = StreamController<PresenceState>.broadcast();

  SharedPrefsPresenceRepository(this._kv);

  @override
  Stream<PresenceState> get stateStream => _stateController.stream;

  @override
  Future<Result<PresenceState>> currentState() async {
    try {
      final isSilent = await _kv.getBool(NativeSharedKeys.isSilentModeActive) ?? false;
      if (isSilent) {
        final preSilentId = await _kv.getString(NativeSharedKeys.preSilentStatusId);
        final enteredAtMs = await _kv.getInt(NativeSharedKeys.silentEnteredAt);
        final enteredAt = enteredAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(enteredAtMs)
            : DateTime.now(); // fallback: activado antes de Sem 2
        return Success(SilentMode(
          preSilentId: preSilentId ?? StatusIds.fine,
          enteredAt: enteredAt,
        ));
      }
      final currentId    = await _kv.getString(NativeSharedKeys.currentStatusId);
      final lastManualId = await _kv.getString(NativeSharedKeys.manualStatusId);
      return Success(Normal(
        currentId:    currentId    ?? StatusIds.fine,
        lastManualId: lastManualId,
      ));
    } catch (e, st) {
      return FailureResult(UnexpectedFailure(
        message: 'Error leyendo estado de presencia: $e',
        cause: e,
        stackTrace: st,
      ));
    }
  }

  @override
  Future<Result<Unit>> saveState(PresenceState state) async {
    try {
      switch (state) {
        case Normal(:final currentId, :final lastManualId):
          await _kv.setString(NativeSharedKeys.currentStatusId, currentId);
          if (lastManualId != null) {
            await _kv.setString(NativeSharedKeys.manualStatusId, lastManualId);
          }
          await _kv.remove(NativeSharedKeys.isSilentModeActive);
          await _kv.remove(NativeSharedKeys.preSilentStatusId);
          await _kv.remove(NativeSharedKeys.silentEnteredAt);

        case SilentMode(:final preSilentId, :final enteredAt):
          await _kv.setBool(NativeSharedKeys.isSilentModeActive, true);
          await _kv.setString(NativeSharedKeys.preSilentStatusId, preSilentId);
          await _kv.setInt(
            NativeSharedKeys.silentEnteredAt,
            enteredAt.millisecondsSinceEpoch,
          );

        case BackgroundNotificationActive(:final notifStatusId):
          await _kv.setString(NativeSharedKeys.currentStatusId, notifStatusId);

        case SOSActive():
          await _kv.setString(NativeSharedKeys.currentStatusId, StatusIds.sos);
      }
      _stateController.add(state);
      return Success(Unit.instance);
    } catch (e, st) {
      return FailureResult(UnexpectedFailure(
        message: 'Error guardando estado de presencia: $e',
        cause: e,
        stackTrace: st,
      ));
    }
  }

  void dispose() => _stateController.close();
}
```

**Nota sobre `BackgroundNotificationActive`:** solo actualiza `currentStatusId`. Las claves de Silent Mode no se tocan porque este estado es transitorio y no reemplaza el modo silencioso — conviven.

**Nota sobre `SOSActive`:** solo marca `currentStatusId = 'sos'` en SharedPrefs. Las coordenadas GPS se publican en Firestore vía `FirestorePresencePublisher` (Día 4) — no se persisten en SharedPrefs.

---

## Tarea 4 — Tests: `test/contexts/presence/infrastructure/shared_prefs_presence_repository_test.dart`

Patrón de mock: `SharedPreferences.setMockInitialValues({...})` (mismo que `shared_prefs_kv_store_test.dart`).

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/contexts/presence/infrastructure/shared_prefs_presence_repository.dart';
import 'package:nunakin_app/platform/persistence/shared_prefs_kv_store.dart';
import 'package:nunakin_app/shared/result.dart';
```

Cubrir los 7 escenarios de la tabla:

| # | Escenario | Prefs iniciales | Estado esperado |
|---|-----------|-----------------|-----------------|
| 1 | Cold start vacío | `{}` | `Normal(currentId: 'fine', lastManualId: null)` |
| 2 | Normal con historial | `{current_status_id: 'school', manual_status_id: 'school'}` | `Normal(currentId: 'school', lastManualId: 'school')` |
| 3 | Silent Mode activo con timestamp | `{is_silent_mode_active: true, pre_silent_status_id: 'work', silent_entered_at: <ms>}` | `SilentMode(preSilentId: 'work', enteredAt: <DateTime>)` |
| 4 | Silent sin `entered_at` (legado) | `{is_silent_mode_active: true, pre_silent_status_id: 'home'}` | `SilentMode(preSilentId: 'home', enteredAt: ~now)` |
| 5 | `saveState(Normal)` limpia claves Silent | prefs con silent activo | prefs sin `isSilentModeActive`, sin `preSilentStatusId`, sin `silentEnteredAt` |
| 6 | `saveState(SilentMode)` escribe 3 claves | `{}` | `isSilentModeActive=true`, `preSilentStatusId` y `silentEnteredAt` presentes |
| 7 | `stateStream` emite tras `saveState` | — | stream emite el nuevo estado |

**Nota de implementación en los tests:** construir el `SharedPrefsPresenceRepository` con un `SharedPrefsKvStore` real (mismo patrón que el test del KvStore). No usar mocks de `KvStore` — el objetivo es probar la lógica de mapeo estado↔prefs, no el KvStore en sí.

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `lib/platform/persistence/native_keys.dart` | Modificado | + `silentEnteredAt` |
| `android/.../SharedKeys.kt` | Modificado | + `SILENT_ENTERED_AT` |
| `lib/contexts/presence/application/ports/presence_repository.dart` | Nuevo | Puerto abstracto |
| `lib/contexts/presence/infrastructure/shared_prefs_presence_repository.dart` | Nuevo | Impl concreta |
| `test/contexts/presence/infrastructure/shared_prefs_presence_repository_test.dart` | Nuevo | 7 tests |

**Archivos de producción activa no modificados:** `StatusService`, `SilentFunctionalityCoordinator`, `MainActivity`, `InCircleView`, etc.

---

## Riesgos específicos de Día 2

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| `MainActivity.kt` no limpia `silentEnteredAt` al desactivar Silent Mode | Media | Agregar limpieza en el mismo PR en la sección de `MainActivity` que borra `IS_SILENT_MODE_ACTIVE` y `PRE_SILENT_STATUS_ID`. Si se detecta en el smoke test de Día 5, aplicar ahí. |
| Test 4 (legado sin `entered_at`) flaky por comparar `DateTime.now()` | Media | En el test, capturar `before = DateTime.now()` antes de llamar a `currentState()`, y verificar que `enteredAt` esté entre `before` y `DateTime.now()` (rango de ~100 ms). |

---

## Criterios de done

| Criterio | Verificación |
|----------|-------------|
| `PresenceRepository` port en `application/ports/` | Compilación |
| `SharedPrefsPresenceRepository` compila sin tocar archivos de producción activa | `flutter analyze` |
| `NativeSharedKeys.silentEnteredAt` + `SharedKeys.SILENT_ENTERED_AT` sincronizados | Code review |
| Tests cubriendo los 7 escenarios de la tabla | `flutter test --concurrency=1` |
| `flutter analyze` sin warnings nuevos vs. baseline (394) | `flutter analyze` |
| App arranca sin error (DI intacto) | Arrancar en dispositivo |

---

**Siguiente: Día 3 — Use cases `SetManualStatus` + `EnterSilentMode`**
