# Sem 4 — Día 2: `MembershipState` sealed + `CircleRepository` port + `FirestoreCircleRepository`

**Rama:** `refactor/sem4-circle-context`  
**PR:** `refactor(circle): MembershipState sealed + CircleRepository + FirestoreCircleRepository`  
**Fecha planificada:** 2026-05-17  
**Base:** `16ff74f` (main post-PR #185)  
**Modelo:** Sonnet — riesgo bajo. 100% Dart nuevo, patrón idéntico a Día 1.

---

## Contexto

`UserCircleState` vive hoy en `lib/services/circle_service.dart` mezclada con Firestore, `_refreshController` estático, y lógica de negocio. El objetivo es crear el bounded context `circle/` con:

1. `MembershipState` — dominio puro (reemplaza `UserCircleState`).
2. `CircleEntity` — entidad de dominio sin dependencias Firebase.
3. `CircleRepository` — puerto abstracto (stream + getCircle + createCircle).
4. `FirestoreCircleRepository` — impl que delega a `CircleService` y mapea tipos.
5. `CircleViewModel` — patrón idéntico a `IdentityViewModel`.

**Regla de oro (igual que Día 1):** ningún caller existente se migra hoy. `CircleProvider`, `InCircleView`, `CreateCircleView` y demás widgets siguen usando `CircleService` directamente. Solo se crean capas nuevas.

---

## Análisis del código existente

### `UserCircleState` (en `circle_service.dart:67-79`)

```dart
sealed class UserCircleState {}
final class UserInCircle extends UserCircleState { final Circle circle; }
final class UserPendingRequest extends UserCircleState { final String pendingCircleId; }
final class UserNoCircle extends UserCircleState {}
```

`UserInCircle` lleva el objeto `Circle` completo (con `creatorId`). La nueva `MembershipState.UserInCircle` será más liviana: solo `circleId` + `isCreator`. El objeto completo se obtiene vía `getCircle()`.

### `Circle` (en `circle_service.dart:10-35`)

Campos: `id`, `name`, `invitationCode`, `List<String> members`, `creatorId`.  
Tiene `factory Circle.fromFirestore()` — acoplada a Firebase. La nueva `CircleEntity` será pura (sin factory).

### `CircleService` — estado en GetIt

`CircleService` **no está registrado en GetIt**. `CircleProvider` lo instancia con `CircleService()` directamente. Para inyectarlo en `FirestoreCircleRepository`, se registra en `circle_module.dart` como parte de este día.

### `injection_container.dart`

Ya llama `await registerCircleModule(sl)` — **no necesita cambio**.

### Conflicto de nombres

`MembershipState` tendrá subclases con los mismos nombres que `UserCircleState`:
`UserInCircle`, `UserPendingRequest`, `UserNoCircle`.

**Solución:** `firestore_circle_repository.dart` importa `circle_service.dart` con alias:
```dart
import 'package:nunakin_app/services/circle_service.dart' as legacy;
```
Así `legacy.UserInCircle` vs el propio `UserInCircle` del contexto. Sin ambigüedad.

---

## Tarea 1 — `lib/contexts/circle/domain/membership_state.dart`

Dominio puro. Sin imports externos.

```dart
sealed class MembershipState {
  const MembershipState();
}

final class UserNoCircle extends MembershipState {
  const UserNoCircle();
}

final class UserPendingRequest extends MembershipState {
  final String circleId;
  const UserPendingRequest({required this.circleId});
}

final class UserInCircle extends MembershipState {
  final String circleId;
  final bool isCreator;
  const UserInCircle({required this.circleId, required this.isCreator});
}
```

**Por qué `isCreator` aquí y no en `CircleEntity`:** la membresía (quién eres en el círculo) es un concepto de identidad relacional, no una propiedad del círculo en sí. Separar este bit evita cargar `CircleEntity` completo solo para saber si el usuario puede ver el botón de administración.

---

## Tarea 2 — `lib/contexts/circle/domain/circle_entity.dart`

Entidad de dominio pura. Sin `fromFirestore` — el mapeo va en la capa de infraestructura.

```dart
class CircleEntity {
  final String id;
  final String name;
  final String invitationCode;
  final List<String> memberIds;
  final String creatorId;

  const CircleEntity({
    required this.id,
    required this.name,
    required this.invitationCode,
    required this.memberIds,
    required this.creatorId,
  });
}
```

**Por qué `memberIds` y no `members`:** evitar colisión semántica con el campo `members` de Firestore y dejar claro que es una lista de UIDs, no objetos.

---

## Tarea 3 — `lib/contexts/circle/application/ports/circle_repository.dart`

Puerto abstracto. Sin dependencias Firebase.

```dart
import 'package:nunakin_app/contexts/circle/domain/circle_entity.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';

abstract class CircleRepository {
  /// Stream tri-estado de membresía. Emite en cada cambio de Firestore.
  Stream<MembershipState> get membership;

  /// Obtiene los datos completos del círculo por ID.
  Future<CircleEntity?> getCircle(String circleId);

  /// Crea un nuevo círculo y retorna su ID.
  Future<String> createCircle(String name);
}
```

---

## Tarea 4 — `lib/contexts/circle/infrastructure/firestore_circle_repository.dart`

Wrappea `CircleService` (legacy) y mapea `UserCircleState` → `MembershipState`.  
Recibe `CircleService`, `FirebaseFirestore` y `FirebaseAuth` en constructor.

```dart
import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/domain/circle_entity.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';
import 'package:nunakin_app/services/circle_service.dart' as legacy;

class FirestoreCircleRepository implements CircleRepository {
  final legacy.CircleService _service;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreCircleRepository(this._service, this._firestore, this._auth);

  @override
  Stream<MembershipState> get membership =>
      _service.getUserCircleStream().map(_mapState);

  MembershipState _mapState(legacy.UserCircleState state) {
    final currentUid = _auth.currentUser?.uid ?? '';
    return switch (state) {
      legacy.UserInCircle(:final circle) => UserInCircle(
          circleId: circle.id,
          isCreator: circle.creatorId == currentUid,
        ),
      legacy.UserPendingRequest(:final pendingCircleId) =>
        UserPendingRequest(circleId: pendingCircleId),
      legacy.UserNoCircle() => const UserNoCircle(),
    };
  }

  @override
  Future<CircleEntity?> getCircle(String circleId) async {
    assert(circleId.isNotEmpty, 'circleId must not be empty');
    try {
      final doc = await _firestore.collection('circles').doc(circleId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return CircleEntity(
        id: doc.id,
        name: data['name'] as String? ?? '',
        invitationCode: data['invitation_code'] as String? ?? '',
        memberIds: List<String>.from(data['members'] as List? ?? []),
        creatorId: data['creatorId'] as String? ?? '',
      );
    } catch (e) {
      log('[CircleRepository] getCircle error: $e');
      return null;
    }
  }

  @override
  Future<String> createCircle(String name) {
    assert(name.isNotEmpty, 'circle name must not be empty');
    return _service.createCircle(name);
  }
}
```

**Notas de diseño:**
- `membership` es un getter que crea un stream nuevo con `.map()` cada vez que se accede. Está bien porque `CircleViewModel` se suscribe una sola vez en `init()`.
- `_mapState` usa `switch` exhaustivo sobre `legacy.UserCircleState` — si `CircleService` agrega un cuarto estado el compilador lo detecta.
- `getCircle` lee Firestore directamente (no delega a `CircleService.getUserCircle()` para evitar la dependencia en `FirebaseAuth.currentUser` que tiene ese método).

---

## Tarea 5 — `lib/contexts/circle/presentation/view_models/circle_view_model.dart`

Patrón idéntico a `IdentityViewModel`.

```dart
import 'dart:async';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';

class CircleViewModel {
  final CircleRepository _repository;
  StreamSubscription<MembershipState>? _sub;
  MembershipState? _current;

  CircleViewModel({required CircleRepository repository})
      : _repository = repository;

  /// Carga el estado actual y suscribe al stream. Llamar post-login (Sem 5).
  Future<void> init() async {
    _sub = _repository.membership.listen((state) {
      _current = state;
    });
  }

  /// Stream de cambios de membresía.
  Stream<MembershipState> get membershipStream => _repository.membership;

  /// Última snapshot. Null antes de [init].
  MembershipState? get currentSnapshot => _current;

  void dispose() => _sub?.cancel();
}
```

**Diferencia con `IdentityViewModel`:** no hay `get current` en `CircleRepository` (el stream es la fuente de verdad; el estado inicial llega vía el primer evento del stream). Por eso `_current` arranca en `null` incluso después de `init()` hasta que llega el primer evento.

---

## Tarea 6 — Modificar `lib/app/di/modules/circle_module.dart`

Reemplaza el placeholder vacío. **`injection_container.dart` no necesita cambio** (ya llama `registerCircleModule`).

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/infrastructure/firestore_circle_repository.dart';
import 'package:nunakin_app/contexts/circle/presentation/view_models/circle_view_model.dart';
import 'package:nunakin_app/services/circle_service.dart';

Future<void> registerCircleModule(GetIt sl) async {
  // Legacy — CircleService necesita estar en GetIt para ser inyectable
  sl.registerLazySingleton(() => CircleService());

  // Infrastructure
  sl.registerLazySingleton<CircleRepository>(
    () => FirestoreCircleRepository(
      sl<CircleService>(),
      sl<FirebaseFirestore>(),
      sl<FirebaseAuth>(),
    ),
  );

  // Presentation
  sl.registerLazySingleton(
    () => CircleViewModel(repository: sl<CircleRepository>()),
  );
}
```

**Nota:** `CircleProvider` seguirá instanciando `CircleService()` directamente con `final CircleService _service = CircleService()`. Esto crea **dos instancias distintas** de `CircleService`. Es aceptable en Día 2 porque `CircleViewModel` no está conectado a UI todavía. En Sem 5, `CircleProvider` migrará a consumir `CircleRepository` desde GetIt, eliminando la instancia directa.

---

## Tarea 7 — Tests

### `test/contexts/circle/domain/membership_state_test.dart` (4 tests — pure Dart)

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 1 | `UserNoCircle()` | pattern match sin `default`, no es `UserInCircle` |
| 2 | `UserPendingRequest(circleId)` | campo accesible, es const |
| 3 | `UserInCircle(circleId, isCreator)` | ambos campos, `isCreator` correcto |
| 4 | Switch exhaustivo sin default | cubre los 3 casos |

### `test/contexts/circle/application/circle_view_model_test.dart` (5 tests — fake repo)

Usa `_FakeCircleRepository` con `StreamController<MembershipState>`. Sin Firebase.

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 1 | `currentSnapshot` antes de `init()` | es `null` |
| 2 | `init()` suscribe al stream | no lanza, `currentSnapshot` sigue `null` hasta primer evento |
| 3 | `membershipStream` re-emite eventos | listener recibe `UserInCircle` tras emit del fake |
| 4 | `currentSnapshot` se actualiza tras evento | snapshot refleja último estado |
| 5 | `dispose()` sin excepción | no lanza tras cierre del stream |

> **Test 2 — diferencia con `IdentityViewModel`:** `currentSnapshot` permanece `null` después de `init()` porque `CircleRepository` no tiene `get current` — el estado inicial llega como primer evento del stream. El test verifica que `init()` no lanza y que el estado se actualiza correctamente al llegar el primer evento (cubierto por test 4).

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `lib/contexts/circle/domain/membership_state.dart` | Nuevo | Sealed `MembershipState` |
| `lib/contexts/circle/domain/circle_entity.dart` | Nuevo | Entidad de dominio pura |
| `lib/contexts/circle/application/ports/circle_repository.dart` | Nuevo | Puerto abstracto |
| `lib/contexts/circle/infrastructure/firestore_circle_repository.dart` | Nuevo | Impl — wrappea `CircleService` |
| `lib/contexts/circle/presentation/view_models/circle_view_model.dart` | Nuevo | ViewModel |
| `lib/app/di/modules/circle_module.dart` | Modificado | Reemplaza placeholder, +3 registros |
| `test/contexts/circle/domain/membership_state_test.dart` | Nuevo | 4 tests |
| `test/contexts/circle/application/circle_view_model_test.dart` | Nuevo | 5 tests |

**No se toca:** `circle_service.dart`, `circle_provider.dart`, `injection_container.dart`, ningún widget.

---

## Criterios de done

| Criterio | Verificación |
|----------|-------------|
| `flutter test test/contexts/circle/` — 9/9 verde | `flutter test test/contexts/circle/` |
| `flutter analyze` — 0 errores nuevos vs baseline (375) | `flutter analyze` |
| `CircleRepository` accesible vía `GetIt.instance<CircleRepository>()` | Arrancar app — login funciona |
| `CircleService` registrado en GetIt sin doble instancia en flujos activos | Verificar que `CircleProvider` sigue funcionando |
| `MembershipState` no importa nada fuera de `domain/` | Revisar imports |

---

## Riesgos y mitigaciones

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|------------|
| Dos instancias de `CircleService` en memoria | Alta (intencional) | Aceptado: `CircleViewModel` no está conectado a UI. Se resuelve en Sem 5. |
| Conflicto de nombres `UserInCircle` etc. | Media | Import `as legacy` en `firestore_circle_repository.dart` — ningún otro archivo tiene ambos en scope. |
| `membership` getter crea nuevo stream en cada acceso | Baja | `CircleViewModel.init()` llama `_repository.membership` una sola vez. El getter delega a `_service.getUserCircleStream()` que sí crea un nuevo `StreamController` — aceptable por ahora; Sem 5 lo convierte en `StreamController` singleton. |
| `CircleService()` en GetIt falla si `CircleProvider` también lo instancia | No aplica | Son instancias independientes; no hay estado compartido excepto `_refreshController` estático (que seguirá funcionando). |

---

**Siguiente: Día 3 — Circle use cases (`JoinCircle`, `ApproveJoinRequest`, `DeleteAccount`)**  
**Modelo Día 3:** Sonnet (lógica extraída de `CircleService`, sin interdependencias nativas).
