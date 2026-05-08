# Sem 2 - Día 1 — `PresenceState` sealed + `DomainEventBus`

**Rama:** `refactor/sem2-presence-state`

**PR:** `refactor(presence): PresenceState sealed class + DomainEventBus`

**Fecha planificada:** 2026-05-18 (lunes)

**Base:** tag `refactor-sem1-done` → commit `3a9d34a`

---

## Contexto

Primer día de Sem 2 (Presence Context). Toda la semana es aditiva: el código nuevo **no se cablea a la UI**. `StatusService` y `SilentFunctionalityCoordinator` continúan como ruta de producción. `main` siempre verde.

---

## Tarea 1 — `lib/contexts/presence/domain/presence_state.dart`

Modelo canónico sealed que reemplaza los 5 flags dispersos en SharedPrefs:
`current_status_id`, `manual_status_id`, `pre_silent_status_id`, `is_silent_mode_active`, `suppress_next_geofence_check`.

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

## Tarea 2 — `lib/shared/events/domain_event.dart`

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

## Tarea 3 — `lib/shared/events/domain_event_bus.dart`

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

## Tarea 4 — Modificar `lib/app/di/modules/platform_module.dart`

Agregar registro del `DomainEventBus`:

```dart
import 'package:nunakin_app/shared/events/domain_event_bus.dart';
// ... imports existentes ...

Future<void> registerPlatformModule(GetIt sl) async {
  sl.registerLazySingleton<KvStore>(() => SharedPrefsKvStore(sl()));
  sl.registerLazySingleton<DomainEventBus>(DomainEventBus.new);  // ← NUEVO
}
```

---

## Tarea 5 — Tests: `test/contexts/presence/domain/presence_state_test.dart`

Cubrir (7 tests):

| # | Escenario | Qué verifica |
|---|-----------|-------------|
| 1 | `Normal.visibleStatusId` | Devuelve `currentId` |
| 2 | `SilentMode.visibleStatusId` | Devuelve `preSilentId` |
| 3 | `BackgroundNotificationActive` con `manualBeneathId` | `manualBeneathId` tiene precedencia |
| 4 | `BackgroundNotificationActive` sin `manualBeneathId` | Devuelve `notifStatusId` |
| 5 | `SOSActive.visibleStatusId` | Siempre devuelve `StatusIds.sos` |
| 6 | `isSilent` / `isSOS` por subtipo | Flags correctos para los 4 estados |
| 7 | `Normal.copyWith` | Produce nueva instancia con campos actualizados |

---

## Tarea 6 — Tests: `test/shared/events/domain_event_bus_test.dart`

Cubrir (4 tests):

| # | Escenario |
|---|-----------|
| 1 | `publish` → suscriptor recibe el evento |
| 2 | `on<T>` filtra por tipo: `ZoneEntered` no llega al listener de `SessionEnded` |
| 3 | Múltiples suscriptores reciben el mismo evento (broadcast) |
| 4 | `dispose` cierra el stream sin excepción |

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `lib/contexts/presence/domain/presence_state.dart` | Nuevo | Modelo sealed completo |
| `lib/shared/events/domain_event.dart` | Nuevo | Eventos de dominio inter-BC |
| `lib/shared/events/domain_event_bus.dart` | Nuevo | Bus de eventos |
| `lib/app/di/modules/platform_module.dart` | Modificado | + registro `DomainEventBus` |
| `test/contexts/presence/domain/presence_state_test.dart` | Nuevo | 7 tests |
| `test/shared/events/domain_event_bus_test.dart` | Nuevo | 4 tests |

**Archivos de producción activa no modificados** (StatusService, SilentFunctionalityCoordinator, in_circle_view.dart, etc.).

---

## Criterios de done

| Criterio | Verificación |
|----------|-------------|
| `PresenceState` compila | `flutter analyze` |
| `PresenceState` no importa nada fuera de `domain/` y `shared/` | Revisar imports |
| Tests de `PresenceState` en verde (7/7) | `flutter test` |
| Tests de `DomainEventBus` en verde (4/4) | `flutter test` |
| `DomainEventBus` registrado en DI y accesible via `GetIt` | Verificar en test |
| `flutter analyze` sin warnings nuevos vs. baseline (394) | `flutter analyze` |
| Cero cambios funcionales — app se comporta idéntica | Arrancar app y verificar |

---

**Siguiente: Día 2 — `PresenceRepository` port + `SharedPrefsPresenceRepository`**
