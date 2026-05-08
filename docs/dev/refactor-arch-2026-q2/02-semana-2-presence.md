# Semana 2 — Presence Context (corazón del refactor)

> **Período:** lunes 2026-05-18 a viernes 2026-05-22 (5 días hábiles)
> **Premisa:** Todo es aditivo. La UI **no se cablea** a código nuevo. `StatusService` y `SilentFunctionalityCoordinator` continúan como ruta de producción. `main` siempre verde.
> **Riesgo global:** Bajo.
> **Documento padre:** [00-plan-unificado.md](00-plan-unificado.md).

---

## 0. Objetivo

Construir la fuente única de verdad para el estado de presencia del usuario:

- `PresenceState` sealed como modelo canónico (reemplaza los 5 flags dispersos en SharedPrefs).
- `PresenceRepository` como único punto de lectura/escritura de ese estado.
- Use cases con DbC: `SetManualStatus`, `EnterSilentMode`, `ExitSilentMode`, `RaiseSOS`.
- `FirestorePresencePublisher` que extrae la lógica Firestore de `StatusService`.
- `PresenceViewModel` que expone `Stream<PresenceState>` a la UI (sin cablear todavía).
- `DomainEventBus` + eventos iniciales (`ZoneEntered`, `ZoneExited`, `SessionEnded`, `NotificationStatusSelected`).

**Al cierre de la semana, el comportamiento de la app es idéntico al pre-refactor.** Todo el código nuevo pasa por tests, no por flujos activos de producción.

---

## 1. Premisas y reglas de la semana

1. **Cero cambios funcionales.** `StatusService`, `SilentFunctionalityCoordinator` y `in_circle_view.dart` no se tocan.
2. **`domain/` no importa nada fuera de `shared/` y el propio `domain/`.** `StatusType` (con emoji/label) es una preocupación de UI — el dominio trabaja con `String statusId` y `StatusIds` constants.
3. **Los use cases no se invocan desde código de producción en esta semana.** Solo se ejercitan mediante tests.
4. **`PresenceViewModel` existe pero no está conectado a ningún widget.** La conexión se hace en Sem 5.
5. **Cada PR pasa lint + analyzer + tests existentes antes del merge.**
6. **El smoke test al cierre de la semana verifica que nada regresionó**, no que la nueva arquitectura funciona end-to-end en el dispositivo.

---

## 2. Plan día por día

---

### Día 1 (lunes) — `PresenceState` sealed + `DomainEventBus`

**Rama:** `refactor/sem2-presence-state`

**Tareas:**

#### 1. `lib/contexts/presence/domain/presence_state.dart`

```dart
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';

/// Estado canónico de presencia del usuario.
///
/// Un único valor de este tipo reemplaza las 5 claves de SharedPreferences que
/// hoy dispersan el estado: current_status_id, manual_status_id,
/// pre_silent_status_id, is_silent_mode_active, suppress_next_geofence_check.
sealed class PresenceState {
  const PresenceState();

  /// ID del estado visible a los miembros del círculo en este momento.
  String get visibleStatusId;

  bool get isSilent => this is SilentMode;
  bool get isSOS    => this is SOSActive;
}

/// Estado normal: el usuario está disponible e interactuando.
/// [currentId]     — estado que se muestra al círculo (puede ser auto-actualizado
///                   por geofencing o por selección manual).
/// [lastManualId]  — último estado elegido por el usuario. Necesario para
///                   restaurarlo al salir del Modo Silencio y para el testigo
///                   del modal de selección. Null si el usuario nunca eligió uno.
final class Normal extends PresenceState {
  final String  currentId;
  final String? lastManualId;
  const Normal({required this.currentId, this.lastManualId});

  @override
  String get visibleStatusId => currentId;

  Normal copyWith({String? currentId, String? lastManualId}) => Normal(
        currentId:    currentId    ?? this.currentId,
        lastManualId: lastManualId ?? this.lastManualId,
      );
}

/// El usuario activó Modo Silencio. La app está en background.
/// [preSilentId] — estado que tenía justo antes de activar Silent Mode.
///                 El círculo ve este estado mientras dura el silencio.
/// [enteredAt]   — timestamp para detectar silencio prolongado (> N horas)
///                 en futuros checks automáticos.
final class SilentMode extends PresenceState {
  final String   preSilentId;
  final DateTime enteredAt;
  const SilentMode({required this.preSilentId, required this.enteredAt});

  @override
  String get visibleStatusId => preSilentId;
}

/// Una notificación desde la barra de estado activó un nuevo estado.
/// [notifStatusId]   — estado enviado desde la notificación.
/// [manualBeneathId] — estado manual que el usuario tenía antes de la notificación;
///                     se restaura al descartar la notificación.
final class BackgroundNotificationActive extends PresenceState {
  final String  notifStatusId;
  final String? manualBeneathId;
  const BackgroundNotificationActive({
    required this.notifStatusId,
    this.manualBeneathId,
  });

  @override
  String get visibleStatusId => manualBeneathId ?? notifStatusId;
}

/// El usuario activó SOS.
/// [previousId]  — estado que tenía antes del SOS (para restaurar post-resolución).
/// [latitude], [longitude] — coordenadas GPS capturadas al activar.
final class SOSActive extends PresenceState {
  final String previousId;
  final double latitude;
  final double longitude;
  const SOSActive({
    required this.previousId,
    required this.latitude,
    required this.longitude,
  });

  @override
  String get visibleStatusId => StatusIds.sos;
}
```

**Por qué `String` en lugar de `StatusType`:** `StatusType` (con emoji, label, order) es una preocupación de presentación que vive en `lib/core/models/`. El dominio solo necesita la identidad semántica del estado. La capa de infraestructura/presentación mapea `statusId → StatusType` cuando lo necesita para mostrar emoji o enviar a Firestore.

---

#### 2. `lib/shared/events/domain_event.dart`

```dart
/// Eventos de dominio publicados por bounded contexts vía DomainEventBus.
/// Los BCs no se importan mutuamente; se comunican solo a través de estos eventos.
sealed class DomainEvent {
  const DomainEvent();
}

// ── Geofencing ──────────────────────────────────────────────────────────────

class ZoneEntered extends DomainEvent {
  final String zoneId;
  final String userId;
  const ZoneEntered({required this.zoneId, required this.userId});
}

class ZoneExited extends DomainEvent {
  final String zoneId;
  final String userId;
  const ZoneExited({required this.zoneId, required this.userId});
}

// ── Identity ─────────────────────────────────────────────────────────────────

class SessionEnded extends DomainEvent {
  final String userId;
  const SessionEnded({required this.userId});
}

// ── Notifications ─────────────────────────────────────────────────────────────

class NotificationStatusSelected extends DomainEvent {
  final String statusId;
  const NotificationStatusSelected({required this.statusId});
}
```

---

#### 3. `lib/shared/events/domain_event_bus.dart`

```dart
import 'dart:async';
import 'domain_event.dart';

/// Bus de eventos de dominio. Singleton registrado en DI (platform_module).
/// Nunca como static global — inyectar siempre desde GetIt.
class DomainEventBus {
  final _controller = StreamController<DomainEvent>.broadcast();

  Stream<DomainEvent> get events => _controller.stream;

  /// Stream filtrado por tipo de evento.
  Stream<T> on<T extends DomainEvent>() =>
      _controller.stream.whereType<T>();

  void publish(DomainEvent event) => _controller.add(event);

  void dispose() => _controller.close();
}
```

---

#### 4. Modificar `lib/app/di/modules/platform_module.dart`

Agregar registro del `DomainEventBus`:

```dart
import 'package:nunakin_app/shared/events/domain_event_bus.dart';
// ... imports existentes ...

Future<void> registerPlatformModule(GetIt sl) async {
  sl.registerLazySingleton<KvStore>(() => SharedPrefsKvStore(sl()));
  sl.registerLazySingleton<DomainEventBus>(DomainEventBus.new);
}
```

---

#### 5. Tests `test/contexts/presence/domain/presence_state_test.dart`

Cubrir:
- `Normal.visibleStatusId` devuelve `currentId`.
- `SilentMode.visibleStatusId` devuelve `preSilentId` (no el estado del círculo exterior).
- `BackgroundNotificationActive.visibleStatusId`: `manualBeneathId` tiene precedencia; si es null, devuelve `notifStatusId`.
- `SOSActive.visibleStatusId` siempre devuelve `StatusIds.sos`.
- `isSilent` y `isSOS` reportan correcto para cada subtipo.
- `Normal.copyWith` produce nueva instancia con los campos cambiados.

#### 6. Tests `test/shared/events/domain_event_bus_test.dart`

Cubrir:
- `publish` → suscriptor recibe el evento.
- `on<T>` filtra por tipo: `ZoneEntered` no llega al listener de `SessionEnded`.
- Múltiples suscriptores reciben el mismo evento (broadcast).
- `dispose` cierra el stream sin excepción.

---

**Entregable:** PR `refactor(presence): PresenceState sealed class + DomainEventBus`

**Criterio de done:**
- `PresenceState` compila y no importa nada fuera de `domain/` y `shared/`.
- Tests de `PresenceState` y `DomainEventBus` en verde.
- `DomainEventBus` registrado en DI y accesible via `GetIt`.
- `flutter analyze` sin warnings nuevos vs. baseline (394).

---

### Día 2 (martes) — `PresenceRepository` port + impl `SharedPrefsPresenceRepository`

**Rama:** `refactor/sem2-presence-repo`

**Tareas:**

#### 1. Agregar `silentEnteredAt` a `NativeSharedKeys` y `SharedKeys.kt`

**`lib/platform/persistence/native_keys.dart`** — agregar en la sección `// ── Presence`:

```dart
/// Timestamp (ms epoch) de cuándo se activó Silent Mode.
/// Escrito por: EnterSilentMode use case.
/// Leído por: SharedPrefsPresenceRepository.
/// Eliminado por: ExitSilentMode use case.
static const silentEnteredAt = 'silent_entered_at';
```

**`android/.../SharedKeys.kt`** — agregar en el grupo `// Presence`:

```kotlin
const val SILENT_ENTERED_AT = "silent_entered_at"
```

---

#### 2. `lib/contexts/presence/application/ports/presence_repository.dart`

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

#### 3. `lib/contexts/presence/infrastructure/shared_prefs_presence_repository.dart`

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
        final preSilentId   = await _kv.getString(NativeSharedKeys.preSilentStatusId);
        final enteredAtMs   = await _kv.getInt(NativeSharedKeys.silentEnteredAt);
        final enteredAt     = enteredAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(enteredAtMs)
            : DateTime.now(); // fallback: si se activó antes de Sem 2
        return Success(SilentMode(
          preSilentId: preSilentId ?? StatusIds.fine,
          enteredAt:   enteredAt,
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
        cause: e, stackTrace: st,
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
          await _kv.setInt(NativeSharedKeys.silentEnteredAt,
              enteredAt.millisecondsSinceEpoch);

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
        cause: e, stackTrace: st,
      ));
    }
  }

  void dispose() => _stateController.close();
}
```

**Nota sobre `KvStore.getInt`:** verificar que `SharedPrefsKvStore` tiene el método `getInt`/`setInt`. Si no existe, agregar al interfaz y a la impl en esta misma PR (parte del scope de Día 2).

---

#### 4. Tests `test/contexts/presence/infrastructure/shared_prefs_presence_repository_test.dart`

Usar `SharedPreferences.setMockInitialValues({})` para todos los tests. Cubrir:

| Escenario | Prefs iniciales | Estado esperado |
|-----------|-----------------|-----------------|
| Cold start vacío | `{}` | `Normal(currentId: 'fine')` |
| Normal con historial | `{current_status_id: 'school', manual_status_id: 'school'}` | `Normal(currentId: 'school', lastManualId: 'school')` |
| Silent Mode activo | `{is_silent_mode_active: true, pre_silent_status_id: 'work', silent_entered_at: <ms>}` | `SilentMode(preSilentId: 'work', enteredAt: <DateTime>)` |
| Silent sin `entered_at` (legado) | `{is_silent_mode_active: true, pre_silent_status_id: 'home'}` | `SilentMode(preSilentId: 'home', enteredAt: ~now)` |
| `saveState(Normal)` desde Silent | escribe | prefs limpias de silent, solo `current_status_id` |
| `saveState(SilentMode)` | escribe | 3 keys de silent seteadas |
| `stateStream` emite tras `saveState` | — | stream emite nuevo estado |

---

**Entregable:** PR `refactor(presence): PresenceRepository port + SharedPrefsPresenceRepository`

**Criterio de done:**
- `PresenceRepository` port en `application/ports/`.
- Impl en `infrastructure/` compilando sin modificar archivos de producción.
- `KvStore` tiene `getInt`/`setInt` si faltaban.
- `NativeSharedKeys.silentEnteredAt` + `SharedKeys.SILENT_ENTERED_AT` sincronizados.
- Tests cubriendo todos los escenarios de la tabla.

---

### Día 3 (miércoles) — Use cases `SetManualStatus` + `EnterSilentMode`

**Rama:** `refactor/sem2-use-cases-set-enter`

**Tareas:**

#### 1. `lib/contexts/presence/application/ports/presence_publisher.dart`

Puerto de salida hacia Firestore. Separado del repositorio (que solo maneja SharedPrefs).

```dart
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Puerto de publicación: propaga cambios de presencia a sistemas externos.
/// La impl (`FirestorePresencePublisher`) vive en infrastructure/.
abstract class PresencePublisher {
  /// Publica un cambio de estado manual al círculo vía Firestore.
  Future<Result<Unit>> publish({
    required PresenceState state,
    required String userId,
    required String circleId,
  });
}
```

---

#### 2. `lib/contexts/presence/application/use_cases/set_manual_status.dart`

```dart
import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class SetManualStatus {
  final PresenceRepository _repository;
  final PresencePublisher  _publisher;

  SetManualStatus({
    required PresenceRepository repository,
    required PresencePublisher  publisher,
  })  : _repository = repository,
        _publisher  = publisher;

  Future<Result<Unit>> call({
    required String statusId,
    required String userId,
    required String circleId,
  }) async {
    Contract.requires(statusId.isNotEmpty,   'statusId debe ser no vacío');
    Contract.requires(userId.isNotEmpty,     'userId debe ser no vacío');
    Contract.requires(circleId.isNotEmpty,   'circleId debe ser no vacío');

    final newState = Normal(currentId: statusId, lastManualId: statusId);

    final saveResult = await _repository.saveState(newState);
    if (saveResult.isFailure) return saveResult;

    final publishResult = await _publisher.publish(
      state:    newState,
      userId:   userId,
      circleId: circleId,
    );

    Contract.ensures(publishResult.isSuccess || publishResult.isFailure,
        'resultado debe estar definido');
    return publishResult;
  }
}
```

---

#### 3. `lib/contexts/presence/application/use_cases/enter_silent_mode.dart`

```dart
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class EnterSilentMode {
  final PresenceRepository _repository;

  EnterSilentMode({required PresenceRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call({required String userId}) async {
    Contract.requires(userId.isNotEmpty, 'userId debe ser no vacío');

    final currentResult = await _repository.currentState();
    if (currentResult.isFailure) return currentResult as Result<Unit>;
    final current = currentResult.valueOrNull!;

    // Guardia de idempotencia: no re-entrar si ya está en Silent Mode.
    if (current is SilentMode) {
      return Success(Unit.instance);
    }

    // Pre-silencio = último estado manual, o current si no hay manual.
    final preSilentId = switch (current) {
      Normal(:final lastManualId, :final currentId) =>
          lastManualId ?? currentId,
      _ => StatusIds.fine,
    };

    final result = await _repository.saveState(SilentMode(
      preSilentId: preSilentId,
      enteredAt:   DateTime.now(),
    ));

    Contract.ensures(
      result.isFailure || (await _repository.currentState()).valueOrNull is SilentMode,
      'postcondición: estado debe ser SilentMode tras éxito',
    );
    return result;
  }
}
```

---

#### 4. Tests

**`test/contexts/presence/application/set_manual_status_test.dart`**

Cubrir (con fakes de `PresenceRepository` y `PresencePublisher`):
- `call` guarda `Normal` con `currentId = lastManualId = statusId`.
- `call` invoca `publisher.publish` con el estado correcto.
- Si `repository.saveState` falla → no llama a `publisher`, devuelve `FailureResult`.
- `Contract.requires` lanza en debug cuando `statusId` está vacío.
- `Contract.requires` lanza en debug cuando `circleId` está vacío.

**`test/contexts/presence/application/enter_silent_mode_test.dart`**

Cubrir:
- Desde `Normal` → guarda `SilentMode` con `preSilentId = lastManualId`.
- Desde `Normal` sin `lastManualId` → `preSilentId = currentId`.
- Idempotencia: desde `SilentMode` → devuelve `Success` sin escribir.
- `Contract.requires` lanza cuando `userId` está vacío.

---

**Entregable:** PR `refactor(presence): SetManualStatus + EnterSilentMode use cases`

**Criterio de done:**
- Use cases no importan nada de `features/`, `core/services/`, ni `platform/`.
- Fakes de puerto en `test/helpers/` (no mocks con package, clases simples).
- Todos los tests en verde.

---

### Día 4 (jueves) — `ExitSilentMode` + `RaiseSOS` + `FirestorePresencePublisher`

**Rama:** `refactor/sem2-use-cases-exit-sos-publisher`

**Tareas:**

#### 1. `lib/contexts/presence/application/use_cases/exit_silent_mode.dart`

```dart
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class ExitSilentMode {
  final PresenceRepository _repository;

  ExitSilentMode({required PresenceRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call({required String userId}) async {
    Contract.requires(userId.isNotEmpty, 'userId debe ser no vacío');

    final currentResult = await _repository.currentState();
    if (currentResult.isFailure) return currentResult as Result<Unit>;
    final current = currentResult.valueOrNull!;

    // Idempotencia: ya está en Normal, nada que hacer.
    if (current is Normal) return Success(Unit.instance);

    final restoredId = switch (current) {
      SilentMode(:final preSilentId) => preSilentId,
      _                              => StatusIds.fine,
    };

    final result = await _repository.saveState(Normal(
      currentId:    restoredId,
      lastManualId: restoredId,
    ));

    Contract.ensures(
      result.isFailure || (await _repository.currentState()).valueOrNull is Normal,
      'postcondición: estado debe ser Normal tras éxito',
    );
    return result;
  }
}
```

---

#### 2. `lib/contexts/presence/application/use_cases/raise_sos.dart`

```dart
import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class RaiseSOS {
  final PresenceRepository _repository;
  final PresencePublisher  _publisher;

  RaiseSOS({
    required PresenceRepository repository,
    required PresencePublisher  publisher,
  })  : _repository = repository,
        _publisher  = publisher;

  Future<Result<Unit>> call({
    required String userId,
    required String circleId,
    required double latitude,
    required double longitude,
  }) async {
    Contract.requires(userId.isNotEmpty,   'userId debe ser no vacío');
    Contract.requires(circleId.isNotEmpty, 'circleId debe ser no vacío');

    final currentResult = await _repository.currentState();
    if (currentResult.isFailure) return currentResult as Result<Unit>;
    final previousId = currentResult.valueOrNull!.visibleStatusId;

    final sosState = SOSActive(
      previousId: previousId,
      latitude:   latitude,
      longitude:  longitude,
    );

    final saveResult = await _repository.saveState(sosState);
    if (saveResult.isFailure) return saveResult;

    return _publisher.publish(
      state:    sosState,
      userId:   userId,
      circleId: circleId,
    );
  }
}
```

---

#### 3. `lib/contexts/presence/infrastructure/firestore_presence_publisher.dart`

Esta clase extrae la lógica de escritura Firestore de `StatusService.updateUserStatus`.

**Importante:** en Sem 2 coexiste con `StatusService` (que sigue siendo la ruta de producción). La extracción es para tests y para estar lista cuando Sem 5 cablee la UI al nuevo flujo.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';
import 'dart:developer';

/// Adaptador de salida: publica cambios de presencia en Firestore.
///
/// Extrae la lógica de batch write de StatusService para que la
/// ruta de producción (Sem 5+) use use cases en vez del servicio estático.
///
/// En Sem 2, esta clase no se invoca desde código de producción.
/// La cobertura se da vía tests con FakeFirebaseFirestore (o mocks).
class FirestorePresencePublisher implements PresencePublisher {
  final FirebaseFirestore _firestore;

  FirestorePresencePublisher(this._firestore);

  @override
  Future<Result<Unit>> publish({
    required PresenceState state,
    required String userId,
    required String circleId,
  }) async {
    try {
      final statusId = state.visibleStatusId;
      final batch = _firestore.batch();

      final statusData = <String, dynamic>{
        'userId':         userId,
        'statusType':     statusId,
        'timestamp':      FieldValue.serverTimestamp(),
        'autoUpdated':    false,
        'manualOverride': false,
        'locationUnknown': false,
      };

      // SOS: incluir coordenadas si disponibles.
      if (state is SOSActive) {
        statusData['coordinates'] = {
          'latitude':  state.latitude,
          'longitude': state.longitude,
        };
      }

      batch.update(
        _firestore.collection('circles').doc(circleId),
        {'memberStatus.$userId': statusData},
      );

      final historyRef = _firestore
          .collection('circles').doc(circleId)
          .collection('statusEvents').doc();
      batch.set(historyRef, {
        'uid':        userId,
        'statusType': statusId,
        'createdAt':  FieldValue.serverTimestamp(),
        if (state is SOSActive) 'coordinates': {
          'latitude':  state.latitude,
          'longitude': state.longitude,
        },
      });

      await batch.commit().timeout(const Duration(seconds: 10));
      log('[FirestorePresencePublisher] ✅ Publicado: $statusId');
      return Success(Unit.instance);
    } catch (e, st) {
      log('[FirestorePresencePublisher] ❌ Error: $e');
      return FailureResult(NetworkFailure(
        message: 'Error publicando presencia: $e',
        cause: e, stackTrace: st,
      ));
    }
  }
}
```

**Nota — zona context:** `StatusService.updateUserStatus` lee el estado anterior de Firestore para preservar `zoneId`, `zoneName`, `customEmoji` al hacer override manual dentro de una zona. Esta lógica se completa en Sem 4 (Geofencing context). En Sem 2, la publicación omite los campos de zona (el campo queda null). Esto es aceptable porque en Sem 2 el publisher no se usa en producción.

---

#### 4. Tests

**`test/contexts/presence/application/exit_silent_mode_test.dart`**
- Desde `SilentMode(preSilentId: 'work')` → guarda `Normal(currentId: 'work', lastManualId: 'work')`.
- Idempotencia desde `Normal` → `Success` sin escribir.

**`test/contexts/presence/application/raise_sos_test.dart`**
- `previousId` captura `visibleStatusId` del estado actual.
- Invoca `publisher.publish` con `SOSActive`.
- Si `saveState` falla → no llama al publisher.

**`test/contexts/presence/infrastructure/firestore_presence_publisher_test.dart`**
- Usar `fake_cloud_firestore` (ya debe estar en `dev_dependencies`; si no está, proponer instalación al desarrollador antes de implementar).
- Verificar que el batch escribe en `circles/{id}/memberStatus/{uid}` y en `statusEvents/`.
- Para `SOSActive`: verificar que `coordinates` está presente en el write.
- Para `Normal`: verificar que `coordinates` no está.

---

**Entregable:** PR `refactor(presence): ExitSilentMode + RaiseSOS + FirestorePresencePublisher`

**Criterio de done:**
- Los 4 use cases cubren las 4 transiciones del state machine.
- `FirestorePresencePublisher` compila y tiene tests (con fake o mock de Firestore).
- Ningún archivo de producción modificado fuera de `native_keys.dart`/`SharedKeys.kt`.

---

### Día 5 (viernes) — `PresenceViewModel` + DI + cierre de semana

**Rama:** `refactor/sem2-vm-di-close`

**Tareas:**

#### 1. `lib/contexts/presence/presentation/view_models/presence_view_model.dart`

Clase pura Dart — sin `StatefulWidget`, sin `ChangeNotifier`, sin Riverpod todavía. La conexión al widget tree se hace en Sem 5.

```dart
import 'dart:async';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';

/// Expone el estado de presencia como stream para la capa de presentación.
///
/// NO se conecta a la UI todavía — eso ocurre en Sem 5 cuando InCircleView
/// se descompone en widgets que consumen este VM.
class PresenceViewModel {
  final PresenceRepository _repository;
  StreamSubscription<PresenceState>? _sub;
  PresenceState? _current;

  PresenceViewModel({required PresenceRepository repository})
      : _repository = repository;

  /// Inicializa la carga del estado actual y suscripción al stream.
  Future<void> init() async {
    final result = await _repository.currentState();
    _current = result.valueOrNull;
    _sub = _repository.stateStream.listen((state) {
      _current = state;
    });
  }

  /// Stream de cambios de estado. Emite cada vez que el repo persiste.
  Stream<PresenceState> get stateStream => _repository.stateStream;

  /// Última snapshot disponible en memoria (puede ser null antes de [init]).
  PresenceState? get currentSnapshot => _current;

  void dispose() {
    _sub?.cancel();
  }
}
```

---

#### 2. `lib/app/di/modules/presence_module.dart` — reemplazar placeholder

```dart
import 'package:get_it/get_it.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/enter_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/exit_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/raise_sos.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/set_manual_status.dart';
import 'package:nunakin_app/contexts/presence/infrastructure/firestore_presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/infrastructure/shared_prefs_presence_repository.dart';
import 'package:nunakin_app/contexts/presence/presentation/view_models/presence_view_model.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> registerPresenceModule(GetIt sl) async {
  // Infrastructure
  sl.registerLazySingleton<PresenceRepository>(
    () => SharedPrefsPresenceRepository(sl<KvStore>()),
  );
  sl.registerLazySingleton<PresencePublisher>(
    () => FirestorePresencePublisher(sl<FirebaseFirestore>()),
  );

  // Use cases
  sl.registerFactory(
    () => SetManualStatus(repository: sl(), publisher: sl()),
  );
  sl.registerFactory(
    () => EnterSilentMode(repository: sl()),
  );
  sl.registerFactory(
    () => ExitSilentMode(repository: sl()),
  );
  sl.registerFactory(
    () => RaiseSOS(repository: sl(), publisher: sl()),
  );

  // View model
  sl.registerLazySingleton(
    () => PresenceViewModel(repository: sl()),
  );
}
```

**Nota:** `FirebaseFirestore` debe estar registrado en `external_module.dart`. Verificar antes de correr el app.

---

#### 3. Test de integración ligero `test/contexts/presence/presence_integration_test.dart`

Ejercitar el ciclo completo con fakes (sin dispositivo):

```
Normal(fine) → SetManualStatus('school') → Normal(school)
            → EnterSilentMode()         → SilentMode(preSilent: 'school')
            → ExitSilentMode()          → Normal(school)
            → SetManualStatus('sos'*)   — bloqueado por DbC? (ver nota)
```

> **Nota sobre SOS como `SetManualStatus`:** `RaiseSOS` es el path correcto para emergencias (incluye GPS). El test debe verificar que `SetManualStatus(statusId: 'sos')` llega a Firestore como cualquier otro estado (no está bloqueado a nivel de use case — el bloqueo de zona viene de `StatusService._blockedZoneStatusIds` que se mueve a este contexto en Sem 4). Documentar este gap como deuda a resolver.

Verificar que `PresenceViewModel.stateStream` emite los estados en orden.

---

#### 4. Cierre de semana

1. **`flutter test`** — verificar que sigue en verde (el número puede aumentar por los nuevos tests).
2. **`flutter analyze`** — 0 warnings nuevos vs. baseline 394.
3. **Smoke test** en device físico: ciclo Normal → Silent → Normal con backgrounding ≥10 min. Los 6 pasos del smoke test pre-Día 5 de Sem 1 aplican sin cambios.
4. **Tag:** `git tag refactor-sem2-done` en el commit de `main` post-merge.
5. **Memoria de cierre:** `memory/project_refactor_sem2_done.md`.
6. **Borrador Sem 3:** `docs/dev/refactor-arch-2026-q2/03-semana-3-native-bridge.md`.

---

**Entregable:** PR `refactor(presence): PresenceViewModel + DI wiring + Sem 2 close`

**Criterio de done:**
- `presence_module.dart` registra todos los objetos nuevos.
- App arranca y funciona idéntico al baseline (los objetos están en el contenedor pero nada los invoca en producción).
- Test de integración verde.
- Tag `refactor-sem2-done` en remoto.

---

## 3. Estructura de archivos resultante (al cierre de Sem 2)

```
lib/
├── app/
│   └── di/
│       └── modules/
│           ├── platform_module.dart        ← + DomainEventBus
│           └── presence_module.dart        ← reemplaza placeholder
│
├── contexts/
│   └── presence/
│       ├── domain/
│       │   ├── presence_state.dart         ← NUEVO
│       │   └── value_objects/
│       │       └── status_id.dart          ← existente (Sem 1)
│       ├── application/
│       │   ├── ports/
│       │   │   ├── presence_repository.dart    ← NUEVO
│       │   │   └── presence_publisher.dart     ← NUEVO
│       │   └── use_cases/
│       │       ├── set_manual_status.dart      ← NUEVO
│       │       ├── enter_silent_mode.dart      ← NUEVO
│       │       ├── exit_silent_mode.dart       ← NUEVO
│       │       └── raise_sos.dart              ← NUEVO
│       ├── infrastructure/
│       │   ├── shared_prefs_presence_repository.dart  ← NUEVO
│       │   └── firestore_presence_publisher.dart      ← NUEVO
│       └── presentation/
│           └── view_models/
│               └── presence_view_model.dart   ← NUEVO
│
├── platform/
│   └── persistence/
│       └── native_keys.dart    ← + silentEnteredAt
│
├── shared/
│   └── events/
│       ├── domain_event.dart       ← NUEVO
│       └── domain_event_bus.dart   ← NUEVO
│
└── (resto de lib/ intacto)

android/app/src/main/kotlin/com/datainfers/zync/
└── SharedKeys.kt    ← + SILENT_ENTERED_AT

test/
├── contexts/
│   └── presence/
│       ├── domain/
│       │   └── presence_state_test.dart
│       ├── application/
│       │   ├── set_manual_status_test.dart
│       │   ├── enter_silent_mode_test.dart
│       │   ├── exit_silent_mode_test.dart
│       │   └── raise_sos_test.dart
│       ├── infrastructure/
│       │   ├── shared_prefs_presence_repository_test.dart
│       │   └── firestore_presence_publisher_test.dart
│       └── presence_integration_test.dart
└── shared/
    └── events/
        └── domain_event_bus_test.dart
```

**Archivos de producción modificados (mínimos):**

| Archivo | Cambio |
|---------|--------|
| `lib/platform/persistence/native_keys.dart` | + `silentEnteredAt` |
| `android/.../SharedKeys.kt` | + `SILENT_ENTERED_AT` |
| `lib/app/di/modules/platform_module.dart` | + registro `DomainEventBus` |
| `lib/app/di/modules/presence_module.dart` | placeholder → registro completo |

---

## 4. Criterios de aceptación (semana completa)

| # | Criterio | Cómo se verifica |
|---|----------|------------------|
| 1 | App arranca y funciona idéntico al baseline | Smoke test en device físico |
| 2 | `flutter analyze` sin warnings nuevos vs. baseline 394 | `flutter analyze` |
| 3 | Suite de tests existentes verde | `flutter test` |
| 4 | `PresenceState` no importa nada fuera de `domain/` y `shared/` | `flutter analyze` / code review |
| 5 | Use cases no importan `features/`, `core/services/`, ni `platform/` | Code review |
| 6 | Tests de dominio cubren los 4 estados + todas las transiciones | `flutter test --coverage` |
| 7 | `SharedPrefsPresenceRepository` tests cubren todos los escenarios de la tabla | Coverage |
| 8 | `FirestorePresencePublisher` compila y tiene al menos 1 test de escritura | `flutter test` |
| 9 | `PresenceViewModel` registrado en DI y accesible sin error | `GetIt.I.get<PresenceViewModel>()` en test |
| 10 | Tag `refactor-sem2-done` creado en main remoto | `git tag -l` |
| 11 | Memoria de cierre publicada | Archivo en `memory/` |
| 12 | Borrador `03-semana-3-native-bridge.md` publicado | Archivo en `docs/dev/refactor-arch-2026-q2/` |

---

## 5. Tests requeridos (mínimos)

### Nuevos

| Archivo | Tests mínimos |
|---------|---------------|
| `test/contexts/presence/domain/presence_state_test.dart` | 7 (ver Día 1) |
| `test/shared/events/domain_event_bus_test.dart` | 4 (ver Día 1) |
| `test/contexts/presence/infrastructure/shared_prefs_presence_repository_test.dart` | 7 (ver Día 2, tabla) |
| `test/contexts/presence/application/set_manual_status_test.dart` | 5 (ver Día 3) |
| `test/contexts/presence/application/enter_silent_mode_test.dart` | 4 (ver Día 3) |
| `test/contexts/presence/application/exit_silent_mode_test.dart` | 2 (ver Día 4) |
| `test/contexts/presence/application/raise_sos_test.dart` | 3 (ver Día 4) |
| `test/contexts/presence/infrastructure/firestore_presence_publisher_test.dart` | 2 (ver Día 4) |
| `test/contexts/presence/presence_integration_test.dart` | 1 ciclo completo |

### Existentes (no se tocan)

- `test/shared/result_test.dart`, `test/shared/contract_test.dart` — deben seguir en verde.
- `test/platform/persistence/shared_prefs_kv_store_test.dart` — verde.

### Smoke test manual (al cierre de Día 5)

Los mismos 6 pasos del smoke test pre-Día 5 de Sem 1:

1. Login → seleccionar emoji manual ("En clase").
2. Activar Modo Silencio.
3. Backgrounding ≥15 min.
4. Reabrir app: el modal debe mostrar "En clase" como activo.
5. Desactivar Modo Silencio: el estado vuelve a "En clase" en Firestore.
6. Verificar que ningún miembro del círculo ve cambio de estado inesperado.

---

## 6. Riesgos específicos de Sem 2

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| `KvStore` no tiene `getInt`/`setInt` → falla en Día 2 | Media | Verificar al inicio del Día 2; si faltan, agregarlos como parte del PR de ese día (es scope acotado). |
| `fake_cloud_firestore` no está en `dev_dependencies` → test publisher bloqueado | Baja | Verificar antes de implementar Día 4. Si no está: proponer al desarrollador antes de continuar (sección 7 de CLAUDE.md). |
| `Contract.ensures` con `await _repository.currentState()` en postcondición → llama a I/O en test | Media | En el test, reemplazar con assert simple sobre el valor retornado (el `ensures` es para debug runtime, no para tests). |
| `PresenceViewModel` registrado en DI pero nunca inicializado → `currentSnapshot` siempre null | Baja | Documentar que `init()` debe llamarse post-login (Sem 5). No es un bug en Sem 2. |
| El smoke test revela que `NativeSharedKeys.silentEnteredAt` existe en Flutter prefs pero MainActivity (Kotlin) no lo limpia al desactivar Silent Mode | Media | Agregar limpieza de `silentEnteredAt` en MainActivity.kt (misma sección que limpia `flutter.is_silent_mode_active` y `flutter.pre_silent_status_id`). Hacerlo en el PR del Día 2. |

---

## 7. Definición de "done" para Semana 2

Sem 2 está cerrada cuando se cumplen **todos** los criterios de aceptación (§4) y:

- [ ] Todos los PRs mergeados a `main` (mínimo 5 PRs, uno por día).
- [ ] Tag `refactor-sem2-done` creado en remoto.
- [ ] Memoria de cierre publicada en `memory/`.
- [ ] Borrador `03-semana-3-native-bridge.md` publicado.
- [ ] Smoke test de 6 pasos pasado en device físico.
- [ ] `flutter analyze` 394 issues (baseline, 0 nuevos).
- [ ] Ningún archivo de producción activo modificado excepto los 4 listados en §3.

---

## 8. Salida de emergencia

Si al final de cualquier día **un criterio de aceptación falla**:

1. Revertir el PR problemático.
2. Documentar el bloqueo en `docs/dev/refactor-arch-2026-q2/blockers.md`.
3. **Sem 3 NO inicia** hasta que Sem 2 esté cerrada.
4. Si el bloqueo no se resuelve en 24h, replantear con el desarrollador.

**Punto de reversión seguro:** último commit verde en `main` al inicio de Sem 2.

---

## 9. Próximos pasos al cierre

Al cerrar Sem 2, generar:

- `03-semana-3-native-bridge.md` — detalle día por día de Sem 3 (**semana crítica**).
- Memoria de cierre Sem 2 en `memory/`.
- Actualización del §3.2 de `00-plan-unificado.md` si hubo ajustes de scope.

**Prioridades Sem 3** (señales para el documento):

- Feature flag `USE_LEGACY_BRIDGE` en `build.gradle` para rollback rápido.
- Unificar los 7 MethodChannels en `nunakin/bridge` v1 con sealed `NativeEvent`/`NativeCommand`.
- `BridgeRouter.kt`: extraer los handlers de `MainActivity.kt` (996 → ≤300 líneas).
- `StatusUpdateWorker` deja de escribir `flutter.current_status_id` directamente — emite evento al bridge.
- `SilentFunctionalityCoordinator.activateSilentMode` → `EnterSilentMode` use case + `NativeBridge.invoke(ActivateSilentMode())`.
