# Arquitectura — Nunakin App

> Estado: Sem 1–5 completadas (2026-05-27). Sem 6–10 en progreso.
> Esta doc describe solo lo que YA existe en `main`. No incluye diseño futuro.

---

## Principios no negociables

1. **Single Source of Truth por concepto** — un único dueño por dato de dominio.
2. **Dependencias apuntan hacia adentro** — la UI nunca habla con Firestore; el dominio nunca importa Flutter.
3. **Contratos explícitos en los bordes** — Flutter↔Kotlin, App↔Firestore, App↔Prefs son interfaces tipadas, no strings.

---

## Estructura de carpetas (núcleo refactorizado)

```
lib/
├── contexts/
│   ├── identity/         ← Auth, User, Session
│   ├── circle/           ← Membership, JoinRequest, ownership
│   ├── presence/         ← Status, Mode, broadcasting
│   └── geofencing/       ← Zone, ZoneEvent, auto-status
│
├── platform/
│   └── bridge/           ← NativeBridge unificado (1 MethodChannel)
│
└── shared/               ← Result, Failure, Contract, DomainEventBus
```

**Regla de imports** (verificada por `flutter analyze`):
- `domain/` solo importa `shared/`
- `application/` importa `domain/` y `shared/`
- `infrastructure/` implementa puertos de `application/` y es la única capa que importa `platform/`
- `presentation/` consume `application/` y `domain/`

---

## Bounded Contexts

### 1. `contexts/identity/` — Identidad y Sesión

**Responsabilidad:** quién es el usuario y si está autenticado.

| Capa | Archivos clave |
|------|---------------|
| Domain | `session_state.dart` — sealed: `Anonymous \| Authenticated(uid, email)` |
| Domain | `entities/user.dart`, `domain/usecases/` — sign in, sign out, get current user |
| Application | `ports/identity_repository.dart` — interfaz de autenticación |
| Infrastructure | `firebase_identity_repository.dart` — impl Firebase Auth |
| Presentation | `auth_final_page.dart` — ÚNICO archivo activo de auth (login + registro + recuperación) |
| Presentation | `view_models/identity_view_model.dart` — `Stream<SessionState>` |

**Fuente de verdad:** `Firebase Auth` → `IdentityViewModel` → resto de la app.

---

### 2. `contexts/presence/` — Estado de Presencia

**Responsabilidad:** qué estado ve el círculo de un usuario en cada momento.
Este es el contexto más crítico — reemplaza las 7 fuentes de verdad que existían antes del refactor.

#### State Machine

```dart
sealed class PresenceState {
  String get visibleStatusId; // derivado, nunca almacenado
}

Normal                       // estado regular; currentId + lastManualId
SilentMode                   // modo silencio; preSilentId se restaura al salir
BackgroundNotificationActive // notificación activa; notifStatusId + manualBeneathId
SOSActive                    // SOS activo; previousId + coordenadas GPS
```

#### Use Cases

| Use Case | Transición | DbC |
|----------|-----------|-----|
| `SetManualStatus` | Normal(x) → Normal(newId) | userId + circleId no vacíos |
| `EnterSilentMode` | Normal → SilentMode | userId no vacío; idempotente |
| `ExitSilentMode` | SilentMode → Normal(preSilentId) | userId no vacío; idempotente |
| `RaiseSOS` | cualquiera → SOSActive | userId + circleId + coordenadas válidas |

**Comportamiento documentado (T2):** al entrar a `SilentMode` desde `BackgroundNotificationActive`, el `preSilentId` cae a `fine` (el estado BN no se preserva). Restauración de BN post-Silent es deuda de Sem 7.

| Capa | Archivos clave |
|------|---------------|
| Domain | `presence_state.dart`, `value_objects/status_id.dart` |
| Application | `ports/presence_repository.dart`, `ports/presence_publisher.dart`, `use_cases/` |
| Infrastructure | `shared_prefs_presence_repository.dart` — persiste en `KvStore` |
| Infrastructure | `firestore_presence_publisher.dart` — escribe a Firestore |
| Presentation | `view_models/presence_view_model.dart` — `Stream<PresenceState>` |

**Fuente de verdad única:** `SharedPrefsPresenceRepository` vía `KvStore`. Reemplaza las 5 claves dispersas de SharedPrefs anteriores.

---

### 3. `contexts/circle/` — Círculo y Membresía

**Responsabilidad:** a qué círculo pertenece el usuario y cuál es su rol.

#### Estados de membresía

```dart
sealed class MembershipState {}

UserNoCircle       // sin círculo
UserPendingRequest // solicitud enviada, pendiente de aprobación
UserInCircle       // miembro activo (puede ser owner o miembro)
```

#### Use Cases

| Use Case | Descripción |
|----------|-------------|
| `JoinCircle` | Envía solicitud de unión al círculo |
| `ApproveJoinRequest` | Owner aprueba solicitud (solo owner puede) |
| `DeleteAccount` | Limpia circle + presence + session en cascada |

| Capa | Archivos clave |
|------|---------------|
| Domain | `membership_state.dart`, `circle_entity.dart` |
| Application | `ports/circle_repository.dart`, `use_cases/` |
| Infrastructure | `firestore_circle_repository.dart` |
| Presentation | `view_models/circle_view_model.dart` — `Stream<MembershipState>` |

**Regla de negocio:** solo el creador puede eliminar el círculo. Los miembros no pueden salir — solo eliminar cuenta. Ver `REGLAS_NEGOCIO.md §3`.

---

### 4. `contexts/geofencing/` — Geofencing y Estado Automático

**Responsabilidad:** detectar entrada/salida de zonas y disparar cambios de estado automáticos.

#### Use Case principal

`ApplyGeofenceStatus`: consume eventos `ZoneEntered`/`ZoneExited` del `DomainEventBus` y llama a `SetManualStatus` (presence) con el estado de la zona configurada.

| Capa | Archivos clave |
|------|---------------|
| Application | `ports/geofence_status_writer.dart`, `use_cases/apply_geofence_status.dart` |
| Infrastructure | `firestore_geofence_status_writer.dart` |

**Nota:** `GeofencingService` (legacy en `core/services/`) sigue siendo el adaptador que escucha el plugin nativo. Pendiente migración completa en Sem 8.

---

## Platform Layer

### `platform/bridge/` — NativeBridge Unificado

**Responsabilidad:** comunicación Flutter↔Kotlin a través de un único MethodChannel `nunakin/bridge`.
Reemplaza los 7 MethodChannels que existían antes de Sem 3.

```dart
abstract class NativeBridge {
  Stream<NativeEvent> get events;
  Future<T> invoke<T>(NativeCommand<T> cmd);
}
```

#### Eventos (Flutter recibe de Kotlin)

```dart
sealed class NativeEvent {}
StatusUpdatedFromNotification  // notificación cambió el estado
SilentDeactivatedByUser        // usuario desactivó Silent desde barra
GeofenceEntered                // entró a zona configurada
GeofenceExited                 // salió de zona configurada
```

#### Comandos (Flutter envía a Kotlin)

```dart
sealed class NativeCommand<T> {}
ActivateSilentMode      // activar modo silencio
DeactivateSilentMode    // desactivar modo silencio
GetCurrentLocation      // obtener coordenadas GPS
SetUserSession          // sincronizar uid+email con lado nativo
```

| Archivo | Rol |
|---------|-----|
| `native_bridge.dart` | Interfaz abstracta |
| `native_event.dart` | Sealed events tipados |
| `native_command.dart` | Sealed commands tipados |
| `android_native_bridge.dart` | Implementación Android — único canal `nunakin/bridge` |

**Flag `USE_LEGACY_BRIDGE`:** ya en `false` desde Sem 3 (`build.gradle.kts:58`). Los dual code paths en `MainActivity.kt` se eliminan en Sem 7.

---

## Shared Kernel

```
lib/shared/
├── result.dart          ← Result<T> = Success<T> | Failure
├── failure.dart         ← subtypes: Network, Auth, Validation, Domain, Platform, Unexpected
├── contract.dart        ← DbC: Contract.requires / Contract.ensures (no-op en release)
├── unit.dart            ← Unit.instance (void tipado para Result<Unit>)
└── events/
    ├── domain_event.dart     ← sealed DomainEvent (ZoneEntered, SessionEnded, etc.)
    └── domain_event_bus.dart ← StreamController broadcast singleton (en DI)
```

**Design by Contract:** las precondiciones (`Contract.requires`) lanzan `ContractViolation` en debug. En release son no-op — el compilador las elimina con tree-shaking.

---

## Comunicación entre Bounded Contexts

Los BCs no se importan mutuamente. Se comunican vía `DomainEventBus`.

| Publicador | Evento | Suscriptor | Acción |
|-----------|--------|------------|--------|
| `geofencing` | `ZoneEntered` | `presence` | `ApplyGeofenceStatus` |
| `geofencing` | `ZoneExited` | `presence` | restaurar estado previo |
| `identity` | `SessionEnded` | `circle`, `presence`, `geofencing` | cleanup |
| `notifications` | `NotificationStatusSelected` | `presence` | `SetManualStatus` |

---

## Lo que aún NO está refactorizado

| Componente | Ubicación actual | Plan |
|-----------|-----------------|------|
| `StatusService` | `core/services/` — 9+ callers | Sem 7: migrar callers a use cases |
| `SilentFunctionalityCoordinator` | `core/services/` | Sem 7 |
| `QuickActionsHandler` | `quick_actions/` | Sem 7 |
| `NotificationStatusSelector` | `widgets/` | Sem 7 |
| `WidgetService` | `widgets/` | Sem 7 |
| `EmojiDialogActivity.kt` | Android — modal barra superior | Sem 7: alinear keys a `StorageKeys` |
| Geofencing BC completo | `ZoneRepository` aún en legacy | Sem 8 |

---

## Métricas post-Sem 5

| Métrica | Antes (baseline) | Ahora |
|---------|-----------------|-------|
| Fuentes de verdad para "current status" | 7 | 1 (`SharedPrefsPresenceRepository`) |
| MethodChannels activos | 7 | 1 (`nunakin/bridge`) |
| Líneas `in_circle_view.dart` | 3107 | 475 |
| Líneas `status_selector_overlay.dart` | 556 | 301 |
| Servicios estáticos con estado mutable | ~12 | ~6 (pendientes Sem 7) |
| Tests de dominio (presence + circle) | <5% | ~80% |
