# Plan Unificado de Refactor Arquitectónico — 10 Semanas

> **Versión:** 2.0
> **Fecha de inicio:** 2026-05-06
> **Punto base en Git:** tag `mvp-baseline-20260506` (commit `9c3518e`)
> **Lanzamiento estimado MVP:** ~15 de agosto de 2026
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
│   ├── entities/         ← invariantes como métodos de entidad (canX(), assertValid())
│   ├── value_objects/
│   └── events/
│   # policies/ se crea solo si emergen reglas reutilizables fuera de las entidades
├── application/          ← use cases y puertos
│   ├── ports/            ← interfaces consumidas por el contexto
│   └── use_cases/        ← guards de negocio con Contract
├── infrastructure/       ← adapters concretos (Firestore, native, prefs)
│   # ÚNICA capa autorizada a importar platform/
└── presentation/
    ├── widgets/          ← widgets atómicos reutilizables del BC (sin pantallas completas)
    └── view_models/      ← lógica de presentación pura (sin Flutter widgets)
    # Pantallas completas que orquestan múltiples BCs → app/screens/ (Sem 5)
```

**Regla de imports**:

- `domain/` no importa nada fuera de `shared/`.
- `application/` importa solo `domain/` y `shared/`.
- `infrastructure/` implementa interfaces de `application/ports/` y es la **única** capa que puede importar `platform/`.
- `presentation/widgets/` y `presentation/view_models/` consumen `application/use_cases/` y `domain/`. No importan `platform/` ni `infrastructure/` directamente.

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

### 2.5 Comunicación entre Bounded Contexts — DomainEventBus

Los BCs no se importan mutuamente. La comunicación se hace vía un `DomainEventBus` tipado (Dart Streams) registrado como singleton en DI (`platform_module.dart`). Vive en `shared/events/`.

```dart
// shared/events/domain_event.dart
sealed class DomainEvent {}

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

class SessionEnded extends DomainEvent {
  final String userId;
  const SessionEnded({required this.userId});
}

class NotificationStatusSelected extends DomainEvent {
  final String statusId;
  const NotificationStatusSelected({required this.statusId});
}

// shared/events/domain_event_bus.dart
class DomainEventBus {
  final _controller = StreamController<DomainEvent>.broadcast();
  Stream<DomainEvent> get events => _controller.stream;
  void publish(DomainEvent event) => _controller.add(event);
  void dispose() => _controller.close();
}
```

**Flujos activos en Nunakin**:

| Publicador | Evento | Suscriptor | Acción |
|-----------|--------|------------|--------|
| `geofencing` | `ZoneEntered` | `presence` | `SetAutomaticStatus` |
| `geofencing` | `ZoneExited` | `presence` | restaurar estado previo |
| `identity` | `SessionEnded` | `circle`, `presence`, `geofencing`, `notifications` | cleanup |
| `notifications` | `NotificationStatusSelected` | `presence` | `SetPresenceFromNotification` |

**Regla**: el bus es singleton en DI — nunca un static global. Reemplaza las llamadas directas entre servicios estáticos que hoy causan el Efecto Cascada.

### 2.6 Design by Contract (DbC)

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
| 3 | Native Bridge | 1 MethodChannel unificado. `MainActivity.kt` ≤300 líneas. Migración con feature flag. `USE_LEGACY_BRIDGE=false` verificado en device | **Alto — semana crítica** | (TBD al cierre Sem 2) |
| 4 | Identity + Circle | `IdentitySession` reactivo. `MembershipState` extraído. Eliminar static `_refreshController` | Medio | (TBD al cierre Sem 3) |
| 5 | UI descomposición | `in_circle_view.dart` 3091 → ≤500 líneas. Widgets por sub-state. VM como integrador | Medio | (TBD al cierre Sem 4) |
| 6 | Hardening (parcial) | Tests E2E del núcleo, eliminar shims internos, doc canónica, performance baseline | Bajo | (TBD al cierre Sem 5) |
| 7 | Flujos no refactorizados | `emoji_cache_service`, `notification_status_selector`, `quick_actions_handler`, `widget_service`, `EmojiDialogActivity` alineado a KvStore | Medio | (TBD al cierre Sem 6) |
| 8 | Geofencing BC completo | `ZoneRepository` + `ApplyGeofenceStatus` use case + `DomainEventBus` integrado. Cold-start race resuelto estructuralmente | Medio | (TBD al cierre Sem 7) |
| 9 | Seguridad y Compliance | API Key → Cloud Function, Privacy Policy, `ACCESS_BACKGROUND_LOCATION` justification, auditoría logs sensibles, `flutter pub audit` | **Alto** | (TBD al cierre Sem 8) |
| 10 | Launch Readiness + freeze | E2E suite completa, performance vs baseline, eliminación archivos `dev_utils/` legacy, Google Play prep, freeze + tag `mvp-launch-ready` | Bajo | (TBD al cierre Sem 9) |

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

### 3.6 Detalles de Semana 6 — Hardening (parcial)

**Objetivo**: consolidar el núcleo refactorizado antes de expandir a los contextos pendientes.

**Entregables**:
- Borrar shims: `StatusService.updateUserStatus`, `setOfflineStatus`/`clearOfflineStatus`, código comentado en `main.dart` e `injection_container.dart`.
- Tests E2E del núcleo en `integration_test/`: transición Normal→Silent→Normal, BN durante Silent, SOS desde notificación.
- Doc canónica parcial: `docs/dev/architecture.md` con los BCs completados hasta Sem 5.
- Performance baseline provisional: cold start y app resume. Comparar contra `mvp-baseline-20260506`.

---

### 3.7 Detalles de Semana 7 — Flujos no refactorizados

**Objetivo**: eliminar el 40% del código legado que el refactor de Sems 1–6 no alcanzó y donde viven los bugs actuales.

**Archivos objetivo**:

| Archivo | Problema actual | Solución |
|---------|----------------|----------|
| `emoji_cache_service.dart` | Cold-start race: se llama antes de que Auth complete → escribe `configured_zone_types = []` | Eliminar llamada de `main.dart`. Mover responsabilidad a `PresenceRepository.initialize()` ya con Auth garantizado |
| `notification_status_selector.dart` | Usa `StatusType.fallbackPredefined` hardcodeado, no el repositorio | Migrar a `GetAllEmojisForCircle` use case |
| `quick_actions_handler.dart` | Llama directo a `StatusService` estático | Migrar a `SetManualStatus` use case |
| `widget_service.dart` | Estado mutable global compartido con Home Screen widget Android | Migrar escritura a `PresenceRepository`, lectura vía `KvStore` |
| `EmojiDialogActivity.kt` | Lee `configured_zone_types` de SharedPrefs con key hardcodeada | Alinear key a `StorageKeys` del nuevo `KvStore`. Eliminar dependencia implícita en strings |

**Criterio**: cold-start race no reproducible. Ambos modales (Círculo + BN) leen zonas configuradas de la misma fuente con la misma key.

---

### 3.8 Detalles de Semana 8 — Geofencing BC completo

**Objetivo**: el contexto `geofencing` tiene sus propios repositorios y use cases; ya no depende de servicios estáticos.

**Entregables**:
- `ZoneRepository` (port) + `FirestoreZoneRepository` (impl) — extrae lógica de `zone_service.dart`.
- `ZoneEventRepository` (port) + impl — extrae lógica de `zone_event_service.dart`.
- Use case `ApplyGeofenceStatus`: consume `ZoneEntered`/`ZoneExited` del `DomainEventBus`, dispara `SetAutomaticStatus` en el contexto `presence`. Cierra definitivamente MS5.03.
- `geofencing_service.dart` queda como thin adapter que solo escucha el plugin nativo y publica al bus.
- Tests unitarios de `ApplyGeofenceStatus` con mocks del bus y del `PresenceRepository`.

**Criterio**: agregar una zona nueva no requiere tocar más de 1 archivo de dominio.

---

### 3.9 Detalles de Semana 9 — Seguridad y Compliance

**Objetivo**: resolver todos los ítems bloqueantes de CLAUDE.md §15 antes del lanzamiento.

**Entregables**:

| Ítem | Acción concreta |
|------|----------------|
| API Key Anthropic | Verificar ubicación. Si está en cliente → mover a Cloud Function o Remote Config restringido |
| Privacy Policy | Redactar cubriendo: email, nickname, GPS — uso, retención, eliminación. Publicar URL accesible |
| `ACCESS_BACKGROUND_LOCATION` | Documentar justificación para Google Play: "geofencing para estado automático de presencia" |
| `USE_LEGACY_BRIDGE` | Si no se hizo en Sem 3: flip definitivo a `false`, smoke test en device físico, eliminar flag |
| Auditoría logs sensibles | Grep de `debugPrint`/`log` con UIDs, emails, coordenadas → condicionar a `kDebugMode` |
| `flutter pub audit` | Ejecutar y resolver CVEs conocidos |
| Firebase Security Rules | Revisión final contra esquema de datos real. Confirmar reglas de producción |

**Criterio**: checklist de CLAUDE.md §15 "Pendientes pre-lanzamiento" completado al 100%.

---

### 3.10 Detalles de Semana 10 — Launch Readiness + Freeze

**Objetivo**: el producto está listo para producción. Cero deuda crítica.

**Entregables**:
- Tests E2E completos en `integration_test/`: cold start tras 12h, transición Normal→Silent→Normal con GPS, BN durante Silent, SOS con coordenadas reales.
- Performance final: cold start, app resume, memory footprint. Comparar contra `mvp-baseline-20260506`. Registrar en `docs/dev/performance-baseline.md`.
- Eliminar archivos legacy (deuda §13 Alta): `dev_utils/clean_auth.dart`, `dev_utils/clean_firestore.dart`, `main_test.dart`, `main_minimal_test.dart`, carpetas `dev_auth_simple/`, `dev_auth_test/`, `dev_test/`.
- Google Play prep: APK release build, ProGuard/R8 verificado, signing key auditada.
- **Freeze**: solo bug fixes críticos (severity Alta) a partir del día 4.
- Tag `mvp-launch-ready` en el commit final verificado.

---

## 4. Métricas de éxito

| Métrica | Actual | Meta post-Sem 10 |
|---------|--------|------------------|
| Líneas en `MainActivity.kt` | 996 | ≤300 |
| Líneas en `in_circle_view.dart` | 3091 | ≤500 |
| MethodChannels activos | 7 | 1 |
| Fuentes de verdad para "current status" | 7 | 1 |
| Servicios estáticos con estado mutable | ~12 | 0 |
| Cobertura de tests del dominio (presence + circle) | <5% | ≥80% |
| Archivos a tocar para agregar un `StatusType` | 7 | 1 |
| Bugs de desincronización en 7 días post-merge | 5 (en últimos 4 días) | 0 |
| Ítems compliance pre-lanzamiento resueltos (CLAUDE.md §15) | 0/5 | 5/5 |
| Archivos legacy `dev_utils/` eliminados | 0/6 | 6/6 |
| `USE_LEGACY_BRIDGE` activo | `true` | `false` (Sem 3 o Sem 9) |

---

## 5. Riesgos y mitigaciones globales

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| Refactor destapa bugs latentes | Alta | Cada semana es deployable. Tests E2E desde Sem 2. Tag `mvp-baseline-20260506` permite revertir. |
| Sem 3 (bridge) introduce regresión en lifecycle | Media | Feature flag `USE_LEGACY_BRIDGE`. Mantener canales viejos 48h en paralelo. |
| `USE_LEGACY_BRIDGE` aún en `true` al iniciar Sem 9 | Media | Sem 3 debe cerrarse con flip verificado en device. Si no ocurre en Sem 3, Sem 9 lo resuelve como bloqueante antes del compliance. |
| Conflictos de merge con trabajo en curso | Media | Trunk-based actual ayuda. Ramas cortas. PR por sub-entregable, no por semana. |
| Resistencia a abandonar Clean en `features/auth/` | Baja | Auth ya tiene Clean — se mueve tal cual a `contexts/identity/`. |
| API Key Anthropic en cliente (hardcoded o en assets) | Alta | Sem 9 lo detecta y bloquea el lanzamiento hasta resolverlo. No hay workaround aceptable. |
| Lanzamiento se desliza más allá de agosto | Baja | Sem 10 es buffer explícito. Si Sem 7 u 8 atrasan, Sem 10 absorbe o se mueve a post-MVP con feature flag. |

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
