# Bounded Contexts — Reglas de Imports

## Estructura interna de cada contexto

```
contexts/<nombre>/
├── domain/               ← reglas puras, sin imports externos
│   ├── entities/         ← invariantes como métodos de entidad (canX(), assertValid())
│   ├── value_objects/
│   └── events/
│   # policies/ se crea solo si emergen reglas reutilizables fuera de las entidades
├── application/
│   ├── ports/            ← interfaces (repositorios, servicios) consumidas por el contexto
│   └── use_cases/        ← lógica de aplicación; guards de negocio con Contract
├── infrastructure/       ← adapters concretos (Firestore, native bridge, prefs)
│   # ÚNICA capa autorizada a importar platform/
└── presentation/
    ├── widgets/          ← widgets atómicos reutilizables del BC (sin pantallas completas)
    └── view_models/      ← lógica de presentación pura (sin Flutter widgets)
    # Las pantallas completas que orquestan múltiples BCs viven en app/screens/ (Sem 5)
```

## Reglas obligatorias por capa

| Capa | Puede importar | NO puede importar |
|------|----------------|-------------------|
| `domain/` | Solo `shared/` | Todo lo demás |
| `application/` | `domain/`, `shared/` | `infrastructure/`, `presentation/`, Flutter SDK |
| `infrastructure/` | `domain/`, `application/ports/`, `shared/`, `platform/`, paquetes externos | `presentation/` directamente |
| `presentation/` | `application/use_cases/`, `domain/`, `shared/`, Flutter SDK | `infrastructure/` directamente, `platform/` directamente |

## Regla crítica: `platform/` solo desde `infrastructure/`

`platform/bridge/` y `platform/persistence/` son infraestructura transversal.
Solo `infrastructure/` de cada BC puede importarlos. Si un use case necesita el bridge
nativo, lo hace vía un puerto definido en `application/ports/`:

```dart
// ✅ Correcto
// contexts/geofencing/application/ports/geofencing_bridge_port.dart
abstract class GeofencingBridgePort {
  Stream<ZoneEvent> get events;
}

// contexts/geofencing/infrastructure/android_geofencing_bridge_adapter.dart
import 'package:nunakin_app/platform/bridge/native_bridge.dart'; // ← OK

// ❌ Incorrecto
// contexts/geofencing/domain/zone_service.dart
import 'package:nunakin_app/platform/bridge/native_bridge.dart'; // VIOLA la regla
```

## Comunicación entre contextos

Los BCs no se importan mutuamente. La comunicación se hace vía `DomainEventBus`
(tipado, Dart Streams) registrado en DI. Reside en `shared/events/`.

Flujos activos en Nunakin:

| Publicador | Evento | Suscriptor |
|-----------|--------|------------|
| `geofencing` | `ZoneEntered / ZoneExited` | `presence` → `SetAutomaticStatus` |
| `identity` | `SessionEnded` | `circle`, `presence`, `geofencing`, `notifications` → cleanup |
| `notifications` | `NotificationStatusSelected` | `presence` → `SetPresenceFromNotification` |

```dart
// shared/events/domain_event.dart
sealed class DomainEvent {}
class ZoneEntered extends DomainEvent { final ZoneId zoneId; ... }
class SessionEnded extends DomainEvent { final UserId userId; ... }

// geofencing publica, presence escucha — sin conocerse entre sí
// El bus es un singleton en DI (platform_module), no un global estático
```

## Reglas entre contextos

- Un contexto **NO** importa la capa `domain/` de otro contexto directamente.
- La comunicación entre contextos se hace vía `DomainEventBus` (`shared/events/`).
- `shared/` y `platform/` son los únicos módulos transversales — no contienen lógica de negocio.
- `platform/` solo es accesible desde `infrastructure/`.

## Convención de imports (Dart)

Usar siempre **package imports**, nunca relative imports fuera del propio directorio:

```dart
// ✅ Correcto
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';

// ❌ Incorrecto
import '../../../shared/result.dart';
import '../../presence/domain/presence_state.dart';
```

## Enforcement

- `analysis_options.yaml`: `always_use_package_imports` + `directives_ordering` se activan en Sem 2 junto con la migración de código a los contextos.
- La regla de capas (domain no importa infrastructure, nadie importa platform/ salvo infrastructure/) se verifica en code review hasta que `import_lint` sea incorporado.

## Contextos definidos

| Contexto | Responsabilidad |
|----------|-----------------|
| `identity` | Autenticación, sesión de usuario |
| `circle` | Membresía, solicitudes de unión, propiedad del círculo |
| `presence` | Estado del usuario, Modo Silencio, SOS, transiciones |
| `geofencing` | Zonas, eventos de entrada/salida, estado automático |
| `notifications` | Push, persistente, badge |
