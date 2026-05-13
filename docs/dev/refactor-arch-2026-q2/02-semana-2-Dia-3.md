# Sem 2 - Día 3 — `SetManualStatus` + `EnterSilentMode` use cases

**Rama:** `refactor/sem2-use-cases-set-enter`

**PR:** `refactor(presence): SetManualStatus + EnterSilentMode use cases`

**Fecha planificada:** 2026-05-20 (miércoles)

**Base:** PR #156 → commit `f6965d3`

---

## Contexto

Día 3 de Sem 2. Se construyen el puerto de salida `PresencePublisher` y los dos primeros use cases del Presence Context. Todo el código nuevo es aditivo — **no se invoca desde producción**. `StatusService` y `SilentFunctionalityCoordinator` siguen siendo la ruta activa.

Los use cases se prueban exclusivamente con fakes Dart simples (sin package `mockito`). El patrón de fake reside en `test/helpers/presence/`, compartido entre los tests de Día 3 y los de Día 4.

**Estado del repo al inicio:**
- `lib/contexts/presence/application/use_cases/.gitkeep` — directorio vacío
- `lib/contexts/presence/application/ports/presence_repository.dart` — ✅ existente (PR #156)
- `lib/app/di/modules/presence_module.dart` — placeholder vacío (se puebla en Día 5)

---

## Tarea 1 — `lib/contexts/presence/application/ports/presence_publisher.dart`

Puerto de salida hacia sistemas externos (Firestore). Separado de `PresenceRepository`, que solo maneja SharedPrefs.

```dart
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Puerto de publicación: propaga cambios de presencia a sistemas externos.
/// La impl concreta (FirestorePresencePublisher) vive en infrastructure/ — Día 4.
abstract class PresencePublisher {
  /// Publica un cambio de estado al círculo vía Firestore.
  Future<Result<Unit>> publish({
    required PresenceState state,
    required String userId,
    required String circleId,
  });
}
```

---

## Tarea 2 — `lib/contexts/presence/application/use_cases/set_manual_status.dart`

```dart
import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/contract.dart';
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
    Contract.requires(statusId.isNotEmpty,  'statusId debe ser no vacío');
    Contract.requires(userId.isNotEmpty,    'userId debe ser no vacío');
    Contract.requires(circleId.isNotEmpty,  'circleId debe ser no vacío');

    final newState = Normal(currentId: statusId, lastManualId: statusId);

    final saveResult = await _repository.saveState(newState);
    if (saveResult.isFailure) return saveResult;

    return _publisher.publish(
      state:    newState,
      userId:   userId,
      circleId: circleId,
    );
  }
}
```

---

## Tarea 3 — `lib/contexts/presence/application/use_cases/enter_silent_mode.dart`

```dart
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/shared/contract.dart';
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

    // Guardia de idempotencia: ya está en Silent Mode, nada que hacer.
    if (current is SilentMode) return Success(Unit.instance);

    // Pre-silencio = último estado manual, o current si no hay manual.
    // postcondición implícita: saveState(SilentMode(...)) garantiza
    // que SharedPrefs quedará en SilentMode si devuelve Success.
    final preSilentId = switch (current) {
      Normal(:final lastManualId, :final currentId) =>
          lastManualId ?? currentId,
      _ => StatusIds.fine,
    };

    return _repository.saveState(SilentMode(
      preSilentId: preSilentId,
      enteredAt:   DateTime.now(),
    ));
  }
}
```

**Nota sobre postcondición:** el plan de Sem 2 proponía un `Contract.ensures` con `await _repository.currentState()`. Esa expresión es `Future<bool>`, no `bool`, y `Contract.ensures` espera `bool` — no compila. La postcondición es innecesaria en runtime porque está garantizada por construcción: si `saveState(SilentMode(...))` devuelve `Success`, el repositorio persistió `SilentMode`. La invariante queda en el comentario de código.

---

## Tarea 4 — Fakes en `test/helpers/presence/`

Clases simples Dart, sin `mockito`. Se reúsan en los tests de Día 3 y Día 4.

### `test/helpers/presence/fake_presence_repository.dart`

```dart
import 'dart:async';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class FakePresenceRepository implements PresenceRepository {
  PresenceState _state = const Normal(currentId: StatusIds.fine);
  Result<Unit>? saveStateOverride;   // null → Success por defecto
  int saveCallCount = 0;
  PresenceState? lastSavedState;

  final _controller = StreamController<PresenceState>.broadcast();

  @override
  Stream<PresenceState> get stateStream => _controller.stream;

  @override
  Future<Result<PresenceState>> currentState() async => Success(_state);

  @override
  Future<Result<Unit>> saveState(PresenceState state) async {
    saveCallCount++;
    lastSavedState = state;
    final result = saveStateOverride ?? Success(Unit.instance);
    if (result.isSuccess) {
      _state = state;
      _controller.add(state);
    }
    return result;
  }

  void dispose() => _controller.close();
}
```

### `test/helpers/presence/fake_presence_publisher.dart`

```dart
import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class FakePresencePublisher implements PresencePublisher {
  Result<Unit> publishResult = Success(Unit.instance);
  int publishCallCount = 0;
  PresenceState? lastPublishedState;
  String? lastUserId;
  String? lastCircleId;

  @override
  Future<Result<Unit>> publish({
    required PresenceState state,
    required String userId,
    required String circleId,
  }) async {
    publishCallCount++;
    lastPublishedState = state;
    lastUserId   = userId;
    lastCircleId = circleId;
    return publishResult;
  }
}
```

---

## Tarea 5 — Tests: `test/contexts/presence/application/set_manual_status_test.dart`

Cubrir los 5 escenarios:

| # | Escenario | Verificación |
|---|-----------|-------------|
| 1 | `call` guarda `Normal(currentId: statusId, lastManualId: statusId)` | `repo.lastSavedState` es `Normal` con ambos campos iguales a `statusId` |
| 2 | `call` invoca `publisher.publish` con `userId` y `circleId` correctos | `publisher.publishCallCount == 1`, `lastUserId`, `lastCircleId` |
| 3 | Si `saveState` falla → no llama al publisher y retorna `FailureResult` | `publisher.publishCallCount == 0`; resultado es `FailureResult` |
| 4 | `Contract.requires` lanza cuando `statusId` está vacío | `await expectLater(call('', 'u1', 'c1'), throwsA(isA<ContractViolation>()))` |
| 5 | `Contract.requires` lanza cuando `circleId` está vacío | `await expectLater(call('fine', 'u1', ''), throwsA(isA<ContractViolation>()))` |

**Patrón de test:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/set_manual_status.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import '../../helpers/presence/fake_presence_repository.dart';
import '../../helpers/presence/fake_presence_publisher.dart';

void main() {
  late FakePresenceRepository repo;
  late FakePresencePublisher publisher;
  late SetManualStatus useCase;

  setUp(() {
    repo      = FakePresenceRepository();
    publisher = FakePresencePublisher();
    useCase   = SetManualStatus(repository: repo, publisher: publisher);
  });

  tearDown(() => repo.dispose());

  // ... 5 tests según tabla
}
```

**Nota sobre los tests de `Contract`:** `Contract.requires` usa `assert`, que está activo en `flutter_test`. Lanza `ContractViolation` sincronamente. Como `call` es `async`, la excepción se captura en el `Future` — usar `await expectLater(future, throwsA(...))` en lugar de `expect(() => ..., throwsA(...))`.

---

## Tarea 6 — Tests: `test/contexts/presence/application/enter_silent_mode_test.dart`

Cubrir los 4 escenarios:

| # | Escenario | Estado inicial | Verificación |
|---|-----------|---------------|-------------|
| 1 | Normal con `lastManualId` → `preSilentId = lastManualId` | `Normal(currentId: 'school', lastManualId: 'school')` | `repo.lastSavedState` es `SilentMode(preSilentId: 'school')` |
| 2 | Normal sin `lastManualId` → `preSilentId = currentId` | `Normal(currentId: 'school', lastManualId: null)` | `SilentMode(preSilentId: 'school')` |
| 3 | Idempotencia: ya en `SilentMode` → `Success` sin escribir | `SilentMode(preSilentId: 'work', enteredAt: ...)` | `repo.saveCallCount == 0`; resultado `Success` |
| 4 | `Contract.requires` lanza cuando `userId` está vacío | — | `await expectLater(call(''), throwsA(isA<ContractViolation>()))` |

**Nota sobre test 1 y 2:** `enteredAt` es `DateTime.now()` — verificar que está en el rango `[before, after]` con ventana de ~100 ms (mismo patrón que test 4 de `SharedPrefsPresenceRepository`).

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `lib/contexts/presence/application/ports/presence_publisher.dart` | Nuevo | Puerto de salida hacia Firestore |
| `lib/contexts/presence/application/use_cases/set_manual_status.dart` | Nuevo | Use case |
| `lib/contexts/presence/application/use_cases/enter_silent_mode.dart` | Nuevo | Use case |
| `test/helpers/presence/fake_presence_repository.dart` | Nuevo | Fake reutilizable (Días 3 y 4) |
| `test/helpers/presence/fake_presence_publisher.dart` | Nuevo | Fake reutilizable (Días 3 y 4) |
| `test/contexts/presence/application/set_manual_status_test.dart` | Nuevo | 5 tests |
| `test/contexts/presence/application/enter_silent_mode_test.dart` | Nuevo | 4 tests |

**Archivos de producción activa no modificados:** `StatusService`, `SilentFunctionalityCoordinator`, `presence_module.dart` (placeholder intacto — se puebla en Día 5), ningún widget.

---

## Riesgos específicos de Día 3

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| `Contract.requires` con Future: `expect(() => call(), throwsA(...))` no captura la excepción | Alta | Usar `await expectLater(call(...), throwsA(isA<ContractViolation>()))` — el error va al Future, no se lanza sincrónicamente |
| `FakePresenceRepository.currentState` debe devolver el estado actualizado post-`saveState` | Media | `_state` se actualiza en `saveState` solo si el resultado es `Success` — ver implementación del fake |
| `EnterSilentMode` test 3 (idempotencia): verificar que `saveCallCount == 0` cuando el fake ya está en `SilentMode` | Baja | Setear `_state = SilentMode(...)` directamente en el fake antes de llamar al use case |

---

## Criterios de done

| Criterio | Verificación |
|----------|-------------|
| `PresencePublisher` port en `application/ports/` | Compilación |
| `SetManualStatus` y `EnterSilentMode` no importan nada de `features/`, `core/services/`, ni `platform/` | `flutter analyze` / revisar imports |
| Fakes en `test/helpers/presence/` — sin dependencias de `mockito` | Revisar `pubspec.yaml` (no se agrega ningún paquete) |
| Tests cubriendo los 9 escenarios de las tablas | `flutter test --concurrency=1` |
| `flutter analyze` sin warnings nuevos vs. baseline (394) | `flutter analyze` |

---

**Siguiente: Día 4 — `ExitSilentMode` + `RaiseSOS` + `FirestorePresencePublisher`**
