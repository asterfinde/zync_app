# Sem 4 - Día 1 — `SessionState` sealed + `IdentityRepository` + `IdentityViewModel`

**Rama:** `refactor/sem4-identity-session`

**PR:** `refactor(identity): SessionState sealed + IdentityRepository + FirebaseIdentityRepository`

**Fecha planificada:** 2026-05-16

**Base:** tag `refactor-sem3-done` → commit `373b450`

**Modelo recomendado:** Sonnet — riesgo bajo. Código 100% Dart nuevo, sin interdependencias nativas, patrón idéntico a Sem 2 Día 1 (`PresenceState` + `SharedPrefsPresenceRepository` + `PresenceViewModel`). Sin migración de callers existentes.

---

## Contexto

Primer día de Sem 4 (Identity + Circle). Hoy `FirebaseAuth.instance` se llama directamente desde servicios, widgets y workers sin una fuente de verdad tipada para la sesión. El objetivo es crear el puerto `IdentityRepository` con su implementación Firebase y exponerla vía `IdentityViewModel`.

**Regla de oro:** ningún caller existente se migra hoy. `auth_final_page.dart`, `circle_provider.dart`, `AuthRemoteDataSourceImpl` y los use cases legacy de auth continúan intocados. `identity_module.dart` acumula los registros nuevos sin eliminar los legacy.

---

## Tarea 1 — `lib/contexts/identity/domain/session_state.dart`

Modelo sealed puro. Sin dependencias externas ni de Firebase. Equivalente a `presence_state.dart`.

```dart
sealed class SessionState {
  const SessionState();
  bool get isAuthenticated => this is Authenticated;
}

final class Anonymous extends SessionState {
  const Anonymous();
}

final class Authenticated extends SessionState {
  final String uid;
  final String email;
  const Authenticated({required this.uid, required this.email});
}
```

**Por qué `String email` y no el objeto `User` de Firebase:** el dominio solo necesita los datos mínimos de identidad. Importar `firebase_auth` en el dominio acoplaría la capa de negocio a un SDK externo — exactamente lo que se quiere eliminar.

---

## Tarea 2 — `lib/contexts/identity/application/ports/identity_repository.dart`

Puerto abstracto. 3 miembros. Ninguna dependencia de Firebase.

```dart
import 'package:nunakin_app/contexts/identity/domain/session_state.dart';

abstract class IdentityRepository {
  /// Stream continuo de cambios de sesión. Emite en cada login/logout.
  Stream<SessionState> get session;

  /// Última snapshot en memoria. `Anonymous` si nunca hubo login.
  SessionState get current;

  /// Cierra la sesión del usuario autenticado.
  Future<void> signOut();
}
```

---

## Tarea 3 — `lib/contexts/identity/infrastructure/firebase_identity_repository.dart`

Implementación concreta. Recibe `FirebaseAuth` en constructor (DI-friendly, testeable sin Firebase). Mapea `authStateChanges()` → `SessionState` vía `StreamController.broadcast()`.

```dart
import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/identity/application/ports/identity_repository.dart';
import 'package:nunakin_app/contexts/identity/domain/session_state.dart';

class FirebaseIdentityRepository implements IdentityRepository {
  final FirebaseAuth _auth;
  final _controller = StreamController<SessionState>.broadcast();
  StreamSubscription<User?>? _sub;
  SessionState _current = const Anonymous();

  FirebaseIdentityRepository(this._auth) {
    _sub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _current = _mapUser(user);
    _controller.add(_current);
    log('[IdentityRepository] session → ${_current.runtimeType}');
  }

  SessionState _mapUser(User? user) => user != null
      ? Authenticated(uid: user.uid, email: user.email ?? '')
      : const Anonymous();

  @override
  Stream<SessionState> get session => _controller.stream;

  @override
  SessionState get current => _current;

  @override
  Future<void> signOut() => _auth.signOut();

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
```

---

## Tarea 4 — `lib/contexts/identity/presentation/view_models/identity_view_model.dart`

Patrón idéntico a `PresenceViewModel`: expone stream + snapshot en memoria. No conecta a UI hoy — la conexión ocurre en Sem 5.

```dart
import 'dart:async';
import 'package:nunakin_app/contexts/identity/application/ports/identity_repository.dart';
import 'package:nunakin_app/contexts/identity/domain/session_state.dart';

class IdentityViewModel {
  final IdentityRepository _repository;
  StreamSubscription<SessionState>? _sub;
  SessionState? _current;

  IdentityViewModel({required IdentityRepository repository})
      : _repository = repository;

  /// Carga el estado actual y suscribe al stream. Llamar post-login (Sem 5).
  Future<void> init() async {
    _current = _repository.current;
    _sub = _repository.session.listen((state) {
      _current = state;
    });
  }

  /// Stream de cambios: emite cada vez que la sesión cambia.
  Stream<SessionState> get sessionStream => _repository.session;

  /// Última snapshot en memoria. Null antes de llamar a [init].
  SessionState? get currentSnapshot => _current;

  void dispose() => _sub?.cancel();
}
```

---

## Tarea 5 — Modificar `lib/app/di/modules/identity_module.dart`

**Agregar al final del archivo.** No eliminar ni tocar los registros legacy de `features/auth/` — se necesitan hasta Día 5.

```dart
// ── NUEVO — Sem 4 Día 1 ───────────────────────────────────────────────────
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/identity/application/ports/identity_repository.dart';
import 'package:nunakin_app/contexts/identity/infrastructure/firebase_identity_repository.dart';
import 'package:nunakin_app/contexts/identity/presentation/view_models/identity_view_model.dart';
```

Y en el cuerpo de `registerIdentityModule`:

```dart
  // Infrastructure
  sl.registerLazySingleton<IdentityRepository>(
    () => FirebaseIdentityRepository(sl<FirebaseAuth>()),
  );

  // Presentation
  sl.registerLazySingleton(
    () => IdentityViewModel(repository: sl<IdentityRepository>()),
  );
```

`sl<FirebaseAuth>()` resuelve correctamente porque `FirebaseAuth.instance` ya está registrado en `external_module.dart`.

---

## Tarea 6 — Tests

### `test/contexts/identity/domain/session_state_test.dart` (4 tests — pure Dart)

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 1 | `Anonymous()` | `isAuthenticated == false`, pattern match sin `default` |
| 2 | `Authenticated(uid, email)` | `isAuthenticated == true`, campos accesibles |
| 3 | Constructores `const` | ambas subclases son `const` |
| 4 | Switch exhaustivo | el compilador no exige `default` al cubrir `Anonymous` y `Authenticated` |

### `test/contexts/identity/application/identity_view_model_test.dart` (5 tests — fake repo)

Usa `_FakeIdentityRepository` handwritten con `StreamController<SessionState>`. Sin Firebase ni paquetes externos.

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 1 | `currentSnapshot` antes de `init()` | es `null` |
| 2 | `init()` carga `current` del repositorio | `currentSnapshot` es `Anonymous` |
| 3 | `sessionStream` re-emite eventos del repo | listener recibe `Authenticated` tras emit del fake |
| 4 | `currentSnapshot` se actualiza tras cada evento | snapshot refleja último estado emitido |
| 5 | `dispose()` cancela suscripción sin excepción | no lanza tras cierre del stream |

> **Nota:** `firebase_identity_repository_test.dart` no se incluye en este día — `firebase_auth_mocks` no está en pubspec y `User` es abstracto. La impl Firebase se valida vía smoke test en Día 5.

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `lib/contexts/identity/domain/session_state.dart` | Nuevo | Sealed class `SessionState` |
| `lib/contexts/identity/application/ports/identity_repository.dart` | Nuevo | Puerto abstracto |
| `lib/contexts/identity/infrastructure/firebase_identity_repository.dart` | Nuevo | Impl Firebase |
| `lib/contexts/identity/presentation/view_models/identity_view_model.dart` | Nuevo | ViewModel |
| `lib/app/di/modules/identity_module.dart` | Modificado | +2 registros al final (legacy intocado) |
| `test/contexts/identity/domain/session_state_test.dart` | Nuevo | 4 tests |
| `test/contexts/identity/application/identity_view_model_test.dart` | Nuevo | 5 tests |

**Archivos de producción activa no modificados:** `auth_final_page.dart`, `circle_provider.dart`, `AuthRemoteDataSourceImpl`, use cases legacy de auth, `FirebaseAuth.instance` callers existentes.

---

## Criterios de done

| Criterio | Verificación |
|----------|-------------|
| `flutter test test/contexts/identity/` — 9/9 verde | `flutter test test/contexts/identity/` |
| `flutter analyze` — 0 errores nuevos vs baseline | `flutter analyze` |
| Los use cases legacy de auth siguen resolviendo en DI | Arrancar app — login funciona |
| `IdentityRepository` accesible vía `GetIt.instance<IdentityRepository>()` | Verificar en test o en app |
| `SessionState` no importa nada fuera de `domain/` | Revisar imports |

---

**Siguiente: Día 2 — `MembershipState` sealed + `CircleRepository` port + `firestore_circle_repository.dart`**
