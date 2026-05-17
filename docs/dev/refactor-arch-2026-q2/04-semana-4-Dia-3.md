# Sem 4 — Día 3: Circle use cases — `JoinCircle`, `ApproveJoinRequest`, `DeleteAccount`

**Rama:** `refactor/sem4-circle-usecases`  
**PR:** `refactor(circle): JoinCircle + ApproveJoinRequest + DeleteAccount use cases`  
**Fecha planificada:** 2026-05-17  
**Base:** `59afb73` (main post-PR #186)  
**Modelo:** Sonnet — riesgo bajo. Lógica extraída de `CircleService`, patrón idéntico a Sem 2 use cases.

---

## Contexto

Hoy la lógica de negocio del círculo está mezclada en `CircleService` y llamada directamente desde widgets:

| Operación | Caller actual | Método del servicio |
|-----------|--------------|---------------------|
| Unirse (enviar solicitud) | `JoinCircleView:53` vía `CircleService()` | `requestToJoinCircle(invitationCode)` |
| Aprobar solicitud | `InCircleView:939` vía `_circleService` | `approveJoinRequest(circleId, userId)` |
| Eliminar cuenta | `SettingsPage:461`, `NoCircleView:159,285` vía `CircleService()` | `deleteAccount()` |

El objetivo es crear use cases que encapsulen estas operaciones detrás del port `CircleRepository`. Los widgets no se migran hoy — eso ocurre en Sem 5.

**Nota sobre `rejectJoinRequest`:** existe en `CircleService` pero no tiene callers en UI (grep confirmado). No se crea use case — YAGNI.

---

## Análisis de dependencias

### `shared/` existente — reusado sin cambios

| Archivo | Uso |
|---------|-----|
| `lib/shared/contract.dart` | `Contract.requires()` — DbC en debug mode |
| `lib/shared/result.dart` | `Result<T>`, `Success<T>`, `FailureResult<T>` |
| `lib/shared/unit.dart` | `Unit.instance` — valor de retorno en success sin datos |
| `lib/shared/failure.dart` | `DomainFailure`, `UnexpectedFailure` — tipado de errores |

Patrón de las impls en `FirestoreCircleRepository`:
```dart
try {
  await _service.theMethod(...);
  return Success(Unit.instance);
} on Exception catch (e) {
  return FailureResult(DomainFailure(message: e.toString(), cause: e));
}
```

---

## Tarea 1 — Extender `lib/contexts/circle/application/ports/circle_repository.dart`

Agregar 3 métodos al final. Los 3 existentes (`membership`, `getCircle`, `createCircle`) no se tocan.

```dart
/// Envía solicitud de ingreso al círculo con el código dado.
/// El usuario queda en estado pendiente hasta que el creador apruebe.
Future<Result<Unit>> requestToJoin(String invitationCode);

/// Aprueba la solicitud de [requestingUserId] en [circleId].
/// El servicio verifica que el caller sea el creador — lanza si no lo es.
Future<Result<Unit>> approveJoin({
  required String circleId,
  required String requestingUserId,
});

/// Elimina la cuenta del usuario autenticado.
/// Si es creador: borra el círculo. Si es miembro: sale del círculo.
/// Orquesta: Firestore cleanup → Firebase Auth delete.
Future<Result<Unit>> deleteAccount();
```

Imports a agregar en el encabezado:
```dart
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';
```

---

## Tarea 2 — Implementar en `lib/contexts/circle/infrastructure/firestore_circle_repository.dart`

Agregar 3 implementaciones al final de la clase. El resto intocado.

Imports a agregar:
```dart
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';
```

```dart
@override
Future<Result<Unit>> requestToJoin(String invitationCode) async {
  try {
    await _service.requestToJoinCircle(invitationCode);
    return Success(Unit.instance);
  } on Exception catch (e) {
    return FailureResult(DomainFailure(message: e.toString(), cause: e));
  }
}

@override
Future<Result<Unit>> approveJoin({
  required String circleId,
  required String requestingUserId,
}) async {
  try {
    await _service.approveJoinRequest(circleId, requestingUserId);
    return Success(Unit.instance);
  } on Exception catch (e) {
    return FailureResult(DomainFailure(message: e.toString(), cause: e));
  }
}

@override
Future<Result<Unit>> deleteAccount() async {
  try {
    await _service.deleteAccount();
    return Success(Unit.instance);
  } on Exception catch (e) {
    return FailureResult(UnexpectedFailure(message: e.toString(), cause: e));
  }
}
```

**Por qué `DomainFailure` para approve y `UnexpectedFailure` para delete:**
- `approveJoin` puede fallar por reglas de negocio esperadas ("no eres el creador", "ya es miembro") → `DomainFailure`.
- `deleteAccount` puede fallar por razones más variadas (red, requires-recent-login, etc.) → `UnexpectedFailure` como fallback.

---

## Tarea 3 — `lib/contexts/circle/application/use_cases/join_circle.dart`

```dart
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class JoinCircle {
  final CircleRepository _repository;

  JoinCircle({required CircleRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call(String invitationCode) async {
    Contract.requires(
      invitationCode.isNotEmpty,
      'invitationCode must not be empty',
    );
    return _repository.requestToJoin(invitationCode);
  }
}
```

---

## Tarea 4 — `lib/contexts/circle/application/use_cases/approve_join_request.dart`

```dart
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class ApproveJoinRequest {
  final CircleRepository _repository;

  ApproveJoinRequest({required CircleRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call({
    required String circleId,
    required String requestingUserId,
  }) async {
    Contract.requires(circleId.isNotEmpty, 'circleId must not be empty');
    Contract.requires(
      requestingUserId.isNotEmpty,
      'requestingUserId must not be empty',
    );
    return _repository.approveJoin(
      circleId: circleId,
      requestingUserId: requestingUserId,
    );
  }
}
```

**Nota:** la verificación "solo el creador puede aprobar" la enforza `CircleService.approveJoinRequest()` (ya existe). El use case no duplica esa lógica — el `DomainFailure` propagado desde el repo es suficiente. El `Contract.requires` solo guarda los invariantes de datos (IDs no vacíos).

---

## Tarea 5 — `lib/contexts/circle/application/use_cases/delete_account.dart`

```dart
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class DeleteAccount {
  final CircleRepository _repository;

  DeleteAccount({required CircleRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call() => _repository.deleteAccount();
}
```

Sin `Contract.requires`: el servicio ya valida `_auth.currentUser != null` y lanza si no hay sesión. Esa validación ocurre en la capa de infraestructura, no en el dominio.

---

## Tarea 6 — Modificar `lib/app/di/modules/circle_module.dart`

Agregar imports y 3 registros al final de `registerCircleModule`. El resto intocado.

Imports a agregar:
```dart
import 'package:nunakin_app/contexts/circle/application/use_cases/approve_join_request.dart';
import 'package:nunakin_app/contexts/circle/application/use_cases/delete_account.dart';
import 'package:nunakin_app/contexts/circle/application/use_cases/join_circle.dart';
```

Registros a agregar al final de la función:
```dart
  // Use cases
  sl.registerLazySingleton(
    () => JoinCircle(repository: sl<CircleRepository>()),
  );
  sl.registerLazySingleton(
    () => ApproveJoinRequest(repository: sl<CircleRepository>()),
  );
  sl.registerLazySingleton(
    () => DeleteAccount(repository: sl<CircleRepository>()),
  );
```

---

## Tarea 7 — Tests

### `test/contexts/circle/application/join_circle_test.dart` (3 tests)

Usa `_FakeCircleRepository` extendido de Día 2 + nuevo campo `requestToJoinResult`.

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 1 | Éxito: repo devuelve `Success` | use case retorna `Success(Unit.instance)` |
| 2 | `invitationCode` vacío | `ContractViolation` lanzado en debug mode |
| 3 | Fallo: repo devuelve `FailureResult` | use case propaga el `FailureResult` |

### `test/contexts/circle/application/approve_join_request_test.dart` (3 tests)

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 1 | Éxito | retorna `Success(Unit.instance)` |
| 2 | `circleId` vacío | `ContractViolation` |
| 3 | `requestingUserId` vacío | `ContractViolation` |

### `test/contexts/circle/application/delete_account_test.dart` (2 tests)

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 1 | Éxito | retorna `Success(Unit.instance)` |
| 2 | Fallo: repo devuelve `FailureResult` | use case propaga el `FailureResult` |

**Total nuevo: 8 tests**

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `lib/contexts/circle/application/ports/circle_repository.dart` | Modificado | +3 métodos al final |
| `lib/contexts/circle/infrastructure/firestore_circle_repository.dart` | Modificado | +3 implementaciones |
| `lib/contexts/circle/application/use_cases/join_circle.dart` | Nuevo | Use case |
| `lib/contexts/circle/application/use_cases/approve_join_request.dart` | Nuevo | Use case |
| `lib/contexts/circle/application/use_cases/delete_account.dart` | Nuevo | Use case |
| `lib/app/di/modules/circle_module.dart` | Modificado | +3 registros use cases |
| `test/contexts/circle/application/join_circle_test.dart` | Nuevo | 3 tests |
| `test/contexts/circle/application/approve_join_request_test.dart` | Nuevo | 3 tests |
| `test/contexts/circle/application/delete_account_test.dart` | Nuevo | 2 tests |

**No se toca:** `circle_service.dart`, `circle_provider.dart`, `join_circle_view.dart`, `in_circle_view.dart`, `settings_page.dart`, `no_circle_view.dart`.

---

## Criterios de done

| Criterio | Verificación |
|----------|-------------|
| `flutter test test/contexts/circle/application/` — todos verdes | `flutter test test/contexts/circle/application/` |
| `flutter analyze` — 0 errores nuevos vs baseline (375) | `flutter analyze` |
| `JoinCircle`, `ApproveJoinRequest`, `DeleteAccount` accesibles en GetIt | `sl.isRegistered<JoinCircle>()` |
| Widgets existentes siguen funcionando (no se tocaron) | `flutter analyze` sin errores nuevos |

---

## Riesgos y mitigaciones

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|------------|
| `Unit` no importado en port/infra | Baja | Verificar imports antes de compilar |
| `ContractViolation` en tests de string vacío | Intencional | Los tests verifican exactamente eso |
| `deleteAccount` en `UnexpectedFailure` vs `AuthFailure` | Baja | `UnexpectedFailure` es el fallback correcto; Firebase Auth puede lanzar `FirebaseAuthException` — la infra lo captura como `on Exception` |

---

**Siguiente: Día 4 — `ApplyGeofenceStatus` use case + `DomainEventBus` wiring**  
**Modelo Día 4:** Sonnet
