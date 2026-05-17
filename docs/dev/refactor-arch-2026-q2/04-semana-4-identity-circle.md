# Semana 4 — Identity + Circle

> **Objetivo:** aislar membresía y sesión. Eliminar `CircleService._refreshController` global.  
> **Riesgo:** Medio  
> **Prerrequisito:** Smoke test 6 pasos en device físico PASS + tag `refactor-sem3-done` creado.  
> **Modelo recomendado:** Sonnet (riesgo medio, sin interdependencias nativas)

---

## Entregables de la semana

1. `IdentitySession` con `Stream<SessionState>` — reemplaza usos directos de `FirebaseAuth.instance` en código de negocio.
2. `circle/` context: `CircleRepository` (port) + impl Firestore.
3. `MembershipState` sealed (`UserNoCircle | UserPendingRequest | UserInCircle`) movido a `circle/domain/`.
4. Use cases: `JoinCircle`, `ApproveJoinRequest`, `DeleteAccount`.
5. Use case `ApplyGeofenceStatus` en `geofencing/` — conecta eventos del bridge con `SetAutomaticStatus` en presence.
6. Migración auth: `lib/features/auth/` → `lib/contexts/identity/` (renombrar imports).

---

## Día 1 — `identity/` context + `IdentitySession`

### Objetivo
Crear la fuente única de verdad para la sesión del usuario. Hoy `FirebaseAuth.instance` se llama directamente desde servicios, widgets y workers — esto se extrae a un puerto tipado.

### Archivos a crear

```
lib/contexts/identity/
├── domain/
│   └── session_state.dart         ← sealed: Anonymous | Authenticated
├── application/
│   └── ports/
│       └── identity_repository.dart
├── infrastructure/
│   └── firebase_identity_repository.dart
└── presentation/
    └── view_models/
        └── identity_view_model.dart
lib/app/di/modules/identity_module.dart
```

### `session_state.dart`
```dart
sealed class SessionState {
  const SessionState();
}

class Anonymous extends SessionState {
  const Anonymous();
}

class Authenticated extends SessionState {
  final String uid;
  final String email;
  const Authenticated({required this.uid, required this.email});
}
```

### `identity_repository.dart` (port)
```dart
abstract class IdentityRepository {
  Stream<SessionState> get session;
  SessionState get current;
  Future<void> signOut();
}
```

### `firebase_identity_repository.dart` (impl)
Wrappea `FirebaseAuth.authStateChanges()` y mapea `User?` a `SessionState`.  
Implementa el stream como `BehaviorSubject`-style usando `StreamController.broadcast()`.

### `identity_module.dart`
```dart
void registerIdentityModule(GetIt sl) {
  sl.registerSingleton<IdentityRepository>(FirebaseIdentityRepository());
  sl.registerSingleton<IdentityViewModel>(
    IdentityViewModel(sl<IdentityRepository>()),
  );
}
```

### Tests — `test/contexts/identity/`
- `session_state_test.dart` — constructores, equality, pattern matching exhaustivo
- `firebase_identity_repository_test.dart` — stream emite `Authenticated` y `Anonymous` correctamente

**Criterio de done:** `flutter test test/contexts/identity/` verde, 0 errores en analyze.

---

## Día 2 — `circle/` context skeleton + `MembershipState`

### Objetivo
Extraer el concepto de membresía al círculo a un bounded context propio.  
`UserCircleState` ya existe en `lib/providers/circle_provider.dart` — se mueve a `circle/domain/`.

### Archivos a crear

```
lib/contexts/circle/
├── domain/
│   ├── membership_state.dart      ← sealed (renombrado de UserCircleState)
│   └── circle_entity.dart         ← entidad Circle (extraída de circle_service.dart)
├── application/
│   └── ports/
│       └── circle_repository.dart
├── infrastructure/
│   └── firestore_circle_repository.dart
└── presentation/
    └── view_models/
        └── circle_view_model.dart
lib/app/di/modules/circle_module.dart
```

### `membership_state.dart`
```dart
sealed class MembershipState {
  const MembershipState();
}

class UserNoCircle extends MembershipState {
  const UserNoCircle();
}

class UserPendingRequest extends MembershipState {
  final String circleId;
  const UserPendingRequest({required this.circleId});
}

class UserInCircle extends MembershipState {
  final String circleId;
  final bool isCreator;
  const UserInCircle({required this.circleId, required this.isCreator});
}
```

### `circle_repository.dart` (port)
```dart
abstract class CircleRepository {
  Stream<MembershipState> get membership;
  Future<Circle> getCircle(String circleId);
  Future<Circle> createCircle(String name);
}
```

### Migración `circle_provider.dart`
- `UserCircleState` sealed → alias o eliminación progresiva, callers migrados a `MembershipState`
- `CircleProvider` pasa a consumir `CircleRepository` en lugar de `CircleService` directamente

### Tests — `test/contexts/circle/`
- `membership_state_test.dart` — pattern matching, properties

**Criterio de done:** `flutter test test/contexts/circle/` verde.

---

## Día 3 — Circle use cases

### Objetivo
Extraer la lógica de negocio del círculo de `CircleService` a use cases con DbC.

### Use cases a crear

```
lib/contexts/circle/application/use_cases/
├── join_circle.dart
├── approve_join_request.dart
└── delete_account.dart
```

#### `join_circle.dart`
```dart
class JoinCircle {
  final CircleRepository _repo;

  Future<Result<Unit>> call(String circleId) async {
    Contract.requires(circleId.isNotEmpty, 'circleId must not be empty');
    // lógica extraída de CircleService.joinCircle()
    return _repo.join(circleId);
  }
}
```

#### `approve_join_request.dart`
Extrae lógica de `CircleService.approveJoinRequest()`.  
DbC: solo el creador puede aprobar.

#### `delete_account.dart`
Extrae lógica de `settings_page.dart` — actualmente mezclada con UI.  
Orquesta: sign out → borrar datos Firestore → Firebase Auth delete.  
DbC: requiere re-autenticación previa (ya implementada en UI).

### Tests
- `join_circle_test.dart` — éxito, circleId vacío, ya miembro
- `approve_join_request_test.dart` — éxito, no es creador (debe fallar)
- `delete_account_test.dart` — orquestación correcta

**Criterio de done:** tests verdes, `settings_page.dart` aún no migrado (se hace en Sem 5).

---

## Día 4 — `ApplyGeofenceStatus` use case

### Objetivo
Crear el puente entre `GeofenceEntered`/`GeofenceExited` del `DomainEventBus` y `SetAutomaticStatus` en el contexto `presence`. Cierra definitivamente el coupling entre `GeofencingService` y `StatusService`.

### Archivos a crear

```
lib/contexts/geofencing/application/use_cases/apply_geofence_status.dart
lib/app/di/modules/geofencing_module.dart        ← actualizar
```

### `apply_geofence_status.dart`
```dart
class ApplyGeofenceStatus {
  final DomainEventBus _bus;
  final SetAutomaticStatus _setStatus;
  StreamSubscription? _sub;

  void initialize() {
    _sub = _bus.events.whereType<ZoneEntered>().listen((e) async {
      await _setStatus.call(zoneId: e.zoneId, userId: e.userId);
    });
    _bus.events.whereType<ZoneExited>().listen((e) async {
      await _setStatus.callExit(userId: e.userId);
    });
  }

  void dispose() => _sub?.cancel();
}
```

### Wiring en DI
`geofencing_module.dart`:
```dart
sl.registerSingleton<ApplyGeofenceStatus>(
  ApplyGeofenceStatus(sl<DomainEventBus>(), sl<SetAutomaticStatus>()),
)..initialize();
```

### Relación con `GeofencingService` actual
`GeofencingService` sigue existiendo pero deja de llamar a `_updateUserStatusByZoneEvent()`.  
En cambio, publica al `DomainEventBus`:
```dart
// ANTES (en _detectZoneTransition):
await _updateUserStatusByZoneEvent(isEntry: true, zone: newZone);

// DESPUÉS:
_bus.publish(ZoneEntered(zoneId: newZone.id, userId: user.uid));
```
El método `_updateUserStatusByZoneEvent` queda deprecated (no se borra hasta Sem 8).

### Tests
- `apply_geofence_status_test.dart` — `ZoneEntered` dispara `SetAutomaticStatus`, `ZoneExited` restaura

**Criterio de done:** tests verdes. `GeofencingService` ya no escribe directo a Firestore en entrada/salida.

---

## Día 5 — Migración auth + smoke test + tag

### Objetivo
Mover `lib/features/auth/` → `lib/contexts/identity/` y cerrar la semana con device validation.

### Migración de archivos

| Origen | Destino |
|--------|---------|
| `lib/features/auth/data/` | `lib/contexts/identity/infrastructure/` |
| `lib/features/auth/domain/` | `lib/contexts/identity/domain/` (merge con lo de Día 1) |
| `lib/features/auth/presentation/pages/auth_final_page.dart` | `lib/contexts/identity/presentation/pages/auth_final_page.dart` |
| `lib/features/auth/presentation/provider/auth_state.dart` | Migrar a `IdentityViewModel` de Día 1 |

**Regla:** `auth_final_page.dart` es el ÚNICO archivo activo de auth (CLAUDE.md §12). El resto es legacy — borrar.

**Archivos legacy a borrar:**
- `lib/features/auth/presentation/widgets/` (legacy confirmado en §12)
- `lib/features/auth/data/datasources/auth_local_data_source.dart` y `_impl.dart` si están sin callers activos

### Smoke test pre-tag (6 pasos estándar)
1. Login con cuenta existente → llega a home
2. Estado del usuario carga correctamente en Círculo
3. Cambio de estado manual → refleja en Círculo
4. Silent Mode ON → estado cambia; OFF → emoji previo restaurado
5. Minimizar → maximizar → estado no se resetea
6. Logout → re-login → estado persiste

**Si todos pasan:**
```bash
git tag refactor-sem4-done
git push origin refactor-sem4-done
```

### Criterio de done de Semana 4
- [ ] `flutter analyze` — 0 errores nuevos vs baseline Sem 3
- [ ] `flutter test` — todos los tests verdes
- [ ] Smoke test 6 pasos PASS en device físico
- [ ] Tag `refactor-sem4-done` pusheado
- [ ] Memoria `project_refactor_sem4_done.md` guardada

---

## Métricas objetivo

| Métrica | Baseline (fin Sem 3) | Objetivo Sem 4 |
|---------|---------------------|----------------|
| Tests totales | ~116 ✅ | +30 mínimo |
| `flutter analyze` warnings | 394 | ≤ 394 (0 nuevos) |
| Callers directos de `FirebaseAuth.instance` en negocio | N | 0 fuera de `FirebaseIdentityRepository` |
| Callers directos de `CircleService` en UI | N | reducidos (migración Sem 5 completa) |
| `GeofencingService` escribe directo a Firestore | Sí | No (vía DomainEventBus) |

---

## Riesgos y mitigaciones

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|------------|
| Migración auth rompe flujo de login | Media | `auth_final_page.dart` no cambia su lógica, solo su ubicación y imports |
| `MembershipState` rename rompe callers | Media | Grep todos los callers de `UserCircleState` antes del rename |
| `ApplyGeofenceStatus` + `GeofencingService` duplican escrituras | Media | Eliminar `_updateUserStatusByZoneEvent` inmediatamente tras cablear el bus |
| Smoke test falla por import roto post-migración | Baja | `flutter analyze` cero errores antes de correr smoke test |
