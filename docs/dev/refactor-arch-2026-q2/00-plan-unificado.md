# Plan Unificado de Refactor Arquitectónico — 6 Semanas

> **Versión:** 1.0
> **Fecha de inicio:** 2026-05-06
> **Punto base en Git:** tag `mvp-baseline-20260506` (commit `9c3518e`)
> **Lanzamiento estimado MVP:** ~28 de junio de 2026
> **Premisa operativa:** cada semana es entregable y testeable. `main` siempre verde. Sin big-bang. Estrategia **strangler fig**.

---

## 0. Resumen ejecutivo

La aplicación se encuentra en estado funcional pero arquitectónicamente frágil: cada bug resuelto en las últimas dos semanas (PRs #141–#143, MS5.03, BN+Silent) es manifestación distinta del mismo defecto estructural — **fragmentación del estado y ausencia de bounded contexts**. Sin una refundación arquitectónica antes del lanzamiento, cada feature post-MVP introducirá regresiones de costo creciente.

Este plan establece, en 6 semanas, una arquitectura **Hexagonal pragmática con Bounded Contexts** que cumple tres principios no negociables:

1. **Single Source of Truth por concepto** — un único dueño por dato de dominio.
2. **Dependencias apuntan hacia adentro** — la UI nunca habla con Firestore; el dominio nunca importa Flutter.
3. **Contratos explícitos en los bordes** — Flutter↔Kotlin, App↔Firestore, App↔Prefs son interfaces tipadas, no strings.

---

## 1. Diagnóstico — por qué los fixes puntuales seguirán fallando

### 1.1 Síntomas observados (sesiones 2026-04-28 a 2026-05-05)

| Bug | Causa raíz directa | Causa raíz estructural |
|-----|-------------------|------------------------|
| AUTH-20260505-001 | Modal no cierra tras excepción de red | UI integra control de error que pertenece a use case |
| AUTH-20260505-002 | `StatusUpdateWorker` sobreescribe `flutter.current_status_id` | Dos productores escriben la misma clave sin contrato |
| AUTH-20260505-003 | Pre-silent status no persistido en Flutter prefs | El "estado pre-silent" no es entidad — es flag emergente |
| MS5.03 | Emoji no preservado al reabrir desde Silent Mode | No hay máquina de estados; cada transición se reescribe |
| BN+Silent | `circleId` vacío en `InCircleView.initState` | Race entre observer Auth y carga de Circle |

### 1.2 Defectos estructurales (no de implementación)

- **No hay bounded contexts**: `circle`, `auth`, `geofencing`, `presence` y `native` se llaman entre sí sin fronteras explícitas.
- **No hay capas**: la UI llama directo a Firestore; servicios estáticos invocan UI vía `navigatorKey` global.
- **No hay puertos/adaptadores**: cada servicio depende de implementaciones concretas (`FirebaseFirestore.instance`, `MethodChannel(...)`, `SharedPreferences.getInstance()`).
- **No hay máquina de estados**: Modo Normal / Silent / BN / SOS son flags dispersos en 7 ubicaciones, no estados modelados.
- **No hay protocolo nativo versionado**: 7 MethodChannels, cada uno con dialecto propio de strings.

### 1.3 Inventario de la fragmentación crítica

Para responder "¿qué emoji muestra el modal?" hoy se consultan 7 fuentes:

| Capa | Clave / propiedad | Escritor | Lector |
|------|-------------------|----------|--------|
| Firestore | `memberStatus.{uid}.statusType` | `StatusService` | listeners |
| Flutter prefs | `flutter.current_status_id` | `StatusService` + `StatusUpdateWorker` (Kotlin) | `EmojiDialogActivity` |
| Flutter prefs | `flutter.manual_status_id` | `StatusService` | `in_circle_view` |
| Flutter prefs | `flutter.pre_silent_status_id` | `SilentCoordinator` | `in_circle_view` |
| Flutter prefs | `flutter.is_silent_mode_active` | `SilentCoordinator` + `MainActivity` | `in_circle_view` |
| Room (Kotlin) | `NativeStateManager` | `MainActivity.onPause` | `NativeStateBridge` |
| Static fields | `_userHasCircle`, `isSilentModeActive` | varios | in-process |

**El refactor reduce esto a 1 fuente.**

---

## 2. Arquitectura objetivo

### 2.1 Estructura macro

```
lib/
├── contexts/
│   ├── identity/         ← Auth, User, Session
│   ├── circle/           ← Membership, JoinRequest, ownership
│   ├── presence/         ← Status, Mode, broadcasting
│   ├── geofencing/       ← Zone, ZoneEvent, auto-status
│   └── notifications/    ← Push, persistent, badge
│
├── platform/             ← Native bridge unificado y persistencia local
│   ├── bridge/
│   │   ├── native_bridge.dart           (interfaz)
│   │   ├── native_event.dart            (sealed events tipados)
│   │   ├── native_command.dart          (sealed commands tipados)
│   │   └── android_native_bridge.dart   (impl única)
│   └── persistence/
│       ├── kv_store.dart                (interfaz)
│       └── shared_prefs_kv_store.dart   (impl)
│
├── shared/               ← kernel mínimo (Result, Failure, Contract, ValueObjects)
└── app/                  ← composition root, DI, main, theme
```

### 2.2 Estructura interna por bounded context

```
contexts/<nombre>/
├── domain/               ← reglas puras, sin imports externos
│   ├── entities/
│   ├── value_objects/
│   ├── events/
│   └── invariants/
├── application/          ← use cases y puertos
│   ├── ports/            ← interfaces consumidas por el contexto
│   └── use_cases/
├── infrastructure/       ← adapters concretos (Firestore, native, prefs)
└── presentation/         ← view models + widgets propios del contexto
```

**Regla de imports**:

- `domain/` no importa nada fuera de `shared/`.
- `application/` importa solo `domain/` y `shared/`.
- `infrastructure/` implementa interfaces de `application/ports/`.
- `presentation/` consume `application/use_cases/` y `domain/`.

### 2.3 State machine de Presence (pieza crítica)

```dart
// contexts/presence/domain/presence_state.dart
sealed class PresenceState {
  StatusType get visibleStatus; // derivado, no almacenado
}

class Normal extends PresenceState {
  final StatusType current;
  // visibleStatus = current
}

class SilentMode extends PresenceState {
  final StatusType preSilent;
  final DateTime enteredAt;
  // visibleStatus = preSilent
}

class BackgroundNotificationActive extends PresenceState {
  final StatusType notifStatus;
  final StatusType? manualBeneath;
  // visibleStatus = manualBeneath ?? notifStatus
}

class SOSActive extends PresenceState {
  final StatusType previousState;
  final Coordinates location;
  // visibleStatus = SOS
}
```

**Transiciones**: funciones puras con DbC. Una sola escritura atómica por transición. Validadas por invariantes.

### 2.4 Native Bridge unificado

```dart
abstract class NativeBridge {
  Stream<NativeEvent> get events;
  Future<T> invoke<T>(NativeCommand<T> cmd);
}

sealed class NativeEvent {}
class StatusUpdatedFromNotification extends NativeEvent { final String statusId; }
class SilentDeactivatedByUser extends NativeEvent {}
class GeofenceEntered extends NativeEvent { final String zoneId; }
class GeofenceExited extends NativeEvent { final String zoneId; }

sealed class NativeCommand<T> {}
class ActivateSilentMode extends NativeCommand<void> {}
class DeactivateSilentMode extends NativeCommand<void> {}
class GetCurrentLocation extends NativeCommand<Coordinates> {}
class SetUserSession extends NativeCommand<void> {
  final String uid;
  final String email;
}
```

**Reemplaza** los 7 MethodChannels actuales por **un único canal `nunakin/bridge` v1**. El protocolo es sealed → el compilador exige exhaustividad en pattern matching.

Lado Kotlin: una `BridgeRouter` única + handlers segregados por tipo de evento/comando. `MainActivity.kt` baja de 996 a ≤300 líneas.

### 2.5 Design by Contract (DbC)

DbC se aplica solo en puntos de invariante crítico (entrada/salida de use cases, transiciones de state machine). Evaluación en debug, no-op en release.

```dart
class EnterSilentMode {
  Future<Result<Unit>> call() async {
    Contract.requires(membership.isMember, 'must belong to circle');
    Contract.requires(!session.isLoggingOut, 'cannot enter silent during logout');

    final result = await _stateMachine.transition(PresenceTransition.toSilent);

    Contract.ensures(_stateMachine.current is SilentMode);
    return result;
  }
}
```

### 2.6 Single Source of Truth

| Concepto | Dueño único | Proyección a otras capas |
|----------|-------------|--------------------------|
| Sesión del usuario | `IdentitySession` (memoria + Firebase Auth) | Notificación a Native vía bridge |
| Membresía al círculo | `MembershipRepository` (Firestore) | Cache en `KvStore` para cold start |
| Estado de presencia | `PresenceRepository` (state machine + Firestore) | Cache en `KvStore` para EmojiDialogActivity |
| Zonas activas | `ZoneRepository` (Firestore) | Cache nativo para geofencing engine |

---

## 3. Plan semana por semana

| Semana | Tema | Entregable principal | Riesgo | Doc detalle |
|--------|------|----------------------|--------|-------------|
| 1 | Cimientos | Estructura, DI real, `Result`, `KvStore`, contratos compartidos, hooks DbC | Bajo | [01-semana-1-cimientos.md](01-semana-1-cimientos.md) |
| 2 | Presence (corazón) | State machine + repository + use cases. Sin cablear UI todavía | Bajo | (TBD al cierre Sem 1) |
| 3 | Native Bridge | 1 MethodChannel unificado. `MainActivity.kt` ≤300 líneas. Migración con feature flag | **Alto — semana crítica** | (TBD al cierre Sem 2) |
| 4 | Identity + Circle | `IdentitySession` reactivo. `MembershipState` extraído. Eliminar static `_refreshController` | Medio | (TBD al cierre Sem 3) |
| 5 | UI descomposición | `in_circle_view.dart` 3091 → ≤500 líneas. Widgets por sub-state. VM como integrador | Medio | (TBD al cierre Sem 4) |
| 6 | Hardening + freeze | Tests E2E, eliminar shims, doc canónica, performance baseline, freeze | Bajo | (TBD al cierre Sem 5) |

### 3.1 Detalles de Semana 1 — Cimientos

Ver [01-semana-1-cimientos.md](01-semana-1-cimientos.md).

### 3.2 Detalles de Semana 2 — Presence

**Objetivo**: existe una sola fuente de verdad para el estado del usuario.

**Entregables**:
- `PresenceState` sealed + transiciones puras + tests unitarios.
- `PresenceRepository` (port) + impl que consolida las 5 SharedPrefs keys actuales en una representación tipada (las claves siguen existiendo; el repo las lee/escribe coherentemente).
- `FirestorePresencePublisher` — extrae la escritura a Firestore desde `StatusService`.
- Use cases: `SetManualStatus`, `EnterSilentMode`, `ExitSilentMode`, `RaiseSOS`. Cada uno con DbC.
- `PresenceViewModel` con `Stream<PresenceState>`. **No se cablea a la UI todavía**.

**Criterio**: máquina de estados con cobertura 100% en transiciones (válidas, inválidas, idempotencia).

### 3.3 Detalles de Semana 3 — Native Bridge (CRÍTICA)

**Objetivo**: el bridge nuevo absorbe los 7 MethodChannels. `StatusService` muere reemplazado por use cases.

**Entregables**:
- `NativeBridge` interfaz + sealed `NativeEvent`/`NativeCommand`. Impl Android.
- Un solo MethodChannel `nunakin/bridge` v1.
- `BridgeRouter.kt`: split de los 7 handlers de `MainActivity` en clases tipadas.
- `MainActivity.kt` ≤300 líneas.
- Migrar `silent_functionality_coordinator` a use case `EnterSilentMode` + `NativeBridge.invoke(ActivateSilentMode())`.
- `StatusService.updateUserStatus` → wrapper deprecado que llama a `SetManualStatus`.
- `StatusUpdateWorker` (Kotlin) ya no escribe `flutter.current_status_id` — emite evento por bridge.

**Mitigación de riesgo**:
- Feature flag `USE_LEGACY_BRIDGE` en build config.
- Canales viejos coexisten 48h post-merge para rollback rápido.
- Tests E2E en device físico antes de cerrar la semana.

### 3.4 Detalles de Semana 4 — Identity + Circle

**Objetivo**: aislar membership y session. Eliminar el `CircleService._refreshController` global.

**Entregables**:
- `IdentitySession` con `Stream<SessionState>` (`Anonymous | Authenticated(uid, email)`). Reemplaza usos directos de `FirebaseAuth.instance` en código de negocio.
- `circle/` context: `CircleRepository` (port) separado de Firestore impl.
- `MembershipState` sealed (`UserNoCircle | UserPendingRequest | UserInCircle`) movido a `circle/domain/`.
- Use cases: `JoinCircle`, `ApproveJoinRequest`, `LeaveCircle`, `DeleteAccount`.
- `geofencing/` context: use case `ApplyGeofenceStatus` que consume `GeofenceEntered` events del bridge y dispara `SetAutomaticStatus` (separado de `SetManualStatus`). Cierra MS5.03/Bug 1.

**Migración auth**: `lib/features/auth/` se mueve a `lib/contexts/identity/` casi sin cambios — la estructura Clean ya existe; solo se renombran imports.

### 3.5 Detalles de Semana 5 — UI

**Objetivo**: la UI consume `PresenceViewModel` y ya no decide. 3091 → ≤500 líneas en `in_circle_view`.

**Entregables**:
- Extraer secciones de `in_circle_view.dart` en widgets: `MemberStatusGrid`, `MyStatusBar`, `ZonePresenceIndicator`, `SilentModeButton`, `JoinRequestsBanner`. Cada uno consume sub-state del VM.
- Extraer `status_selector_overlay.dart` (601 líneas) a widget puro: recibe `currentStatus` + callback `onSelect`. La lógica de prioridad pre_silent/manual/current desaparece — la decide el VM.
- Migrar `auth_final_page.dart` y `settings_page.dart` a use cases en lugar de servicios estáticos.
- `navigatorKey` sigue existiendo solo para `MaterialApp`, no como punto de inyección de servicios.

### 3.6 Detalles de Semana 6 — Hardening

**Objetivo**: eliminar lo legado, sumar coverage, certificar.

**Entregables**:
- Borrar shims: `StatusService.updateUserStatus`, `setOfflineStatus`/`clearOfflineStatus`, `MainActivity.kt.backup_*`, código comentado en `main.dart` e `injection_container.dart`.
- Tests E2E en `integration_test/`: cold start tras 12h, transición Normal→Silent→Normal, BN durante Silent, SOS desde notificación.
- Auditoría de `debugPrint`/`log` con datos sensibles (UIDs, emails, coordenadas) — condicionar a `kDebugMode`.
- Performance baseline: cold start, app resume, memory footprint. Comparar contra `mvp-baseline-20260506`.
- Doc canónica: `docs/dev/architecture.md` (un solo archivo).
- **Freeze**: solo bug fixes críticos a partir del día 5.

---

## 4. Métricas de éxito

| Métrica | Actual | Meta post-Sem 6 |
|---------|--------|------------------|
| Líneas en `MainActivity.kt` | 996 | ≤300 |
| Líneas en `in_circle_view.dart` | 3091 | ≤500 |
| MethodChannels activos | 7 | 1 |
| Fuentes de verdad para "current status" | 7 | 1 |
| Servicios estáticos con estado mutable | ~12 | 0 |
| Cobertura de tests del dominio (presence + circle) | <5% | ≥80% |
| Archivos a tocar para agregar un `StatusType` | 7 | 1 |
| Bugs de desincronización en 7 días post-merge | 5 (en últimos 4 días) | 0 |

---

## 5. Riesgos y mitigaciones globales

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| Refactor destapa bugs latentes | Alta | Cada semana es deployable. Tests E2E desde Sem 2. Tag `mvp-baseline-20260506` permite revertir. |
| Sem 3 (bridge) introduce regresión en lifecycle | Media | Feature flag `USE_LEGACY_BRIDGE`. Mantener canales viejos 48h en paralelo. |
| Lanzamiento se desliza más allá de fines de junio | Media | Sem 6 es buffer. Si Sem 3 atrasa, mover Sem 5 a post-MVP (mantener `in_circle_view` legado pero con datos del VM). |
| Conflictos de merge con trabajo en curso | Media | Trunk-based actual ayuda. Ramas cortas. PR por sub-entregable, no por semana. |
| Resistencia a abandonar Clean en `features/auth/` | Baja | Auth ya tiene Clean — se mueve tal cual a `contexts/identity/`. |

---

## 6. Lo que NO se toca

- **Firestore Security Rules** (sección 6 de `CLAUDE.md`).
- **Esquema de colecciones** (`circles`, `users`, `predefinedEmojis`).
- **Identidad visual / UX flow**.
- **App ID** `com.datainfers.zync`.
- **`KeepAliveService` nativo** — ciclo de vida estable post-PR #77/#79.

---

## 7. Convenciones operativas

### 7.1 Nomenclatura de ramas

```
refactor/sem<N>-<area>          ej. refactor/sem1-foundation
refactor/sem<N>-<area>-<sub>    ej. refactor/sem3-bridge-router
fix/refactor-<descripcion>      ej. fix/refactor-presence-state-leak
```

### 7.2 PR strategy

- **Un PR por sub-entregable**, no por semana.
- Título: `refactor(<context>): <descripción breve>`.
- Cuerpo: referencia al doc de semana correspondiente.
- Cada PR debe pasar lint + tests + smoke test en device físico (cuando aplique).

### 7.3 Definición de "done" por semana

- Todos los entregables de la semana mergeados a `main`.
- Suite de tests verde.
- Doc detalle de la **siguiente** semana publicada en `docs/dev/refactor-arch-2026-q2/`.
- Memoria de cierre de sesión guardada en `memory/`.

### 7.4 Salida de emergencia

Si en cualquier semana el progreso se bloquea por más de 24h:

1. Volver al último PR mergeado verde.
2. Documentar el bloqueo en `docs/dev/refactor-arch-2026-q2/blockers.md`.
3. Reevaluar alcance con el desarrollador antes de continuar.

---

## 8. Referencias

- Tag de referencia: `mvp-baseline-20260506` (commit `9c3518e`).
- Contrato del proyecto: [`CLAUDE.md`](../../../CLAUDE.md).
- Memoria de la última sesión funcional: [`project_session_20260505.md`](../../../C:/Users/dante/.claude/projects/c--Users-dante-projects-zync-app/memory/project_session_20260505.md).
- Detalle Semana 1: [`01-semana-1-cimientos.md`](01-semana-1-cimientos.md).
