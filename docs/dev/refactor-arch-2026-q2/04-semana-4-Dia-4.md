# Semana 4, Día 4 — `ApplyGeofenceStatus` + DomainEventBus wiring

**Fecha:** 2026-05-17
**Rama:** `refactor/sem4-geofence-eventbus`
**Modelo:** Sonnet 4.6

---

## Objetivo

Desacoplar `GeofencingService` de Firestore en el punto de transición de zonas.
Reemplazar las llamadas directas a `_updateUserStatusByZoneEvent()` por publicaciones
al `DomainEventBus`. El nuevo use case `ApplyGeofenceStatus` en `contexts/geofencing/`
recibe los eventos y ejecuta la escritura vía `GeofenceStatusWriter`.

---

## Gaps identificados vs. PA doc original

| Gap | Causa | Solución aplicada |
|-----|-------|------------------|
| `SetAutomaticStatus` no existía | No creado en Sem 2/3 | `GeofenceStatusWriter` (port) + `FirestoreGeofenceStatusWriter` (impl) |
| `ZoneEntered`/`ZoneExited` sin zona metadata | Diseño original mínimo | Nuevos campos opcionales: `circleId`, `zoneTypeValue`, `zoneName`, `isPredefined` |
| `GeofencingService` sin DI | Instanciado en `InCircleView` | Constructor acepta `DomainEventBus?`; `InCircleView` pasa `sl<DomainEventBus>()` |
| `bus.events.whereType<T>()` en PA doc | API incorrecto | Corregido a `_bus.on<T>()` |
| Test `domain_event_bus_test.dart` usaba constructores sin nuevos campos | Nuevos campos son `required` | Todos los nuevos campos son opcionales con defaults; test compila sin cambios |

---

## Archivos creados (4)

| Archivo | Descripción |
|---------|-------------|
| `lib/contexts/geofencing/application/ports/geofence_status_writer.dart` | Port: `onZoneEntered` + `onZoneExited` |
| `lib/contexts/geofencing/application/use_cases/apply_geofence_status.dart` | Use case: suscribe al bus, delega al writer |
| `lib/contexts/geofencing/infrastructure/firestore_geofence_status_writer.dart` | Impl: extrae lógica de `_updateUserStatusByZoneEvent`. Preserva check `manualOverride`. |
| `test/contexts/geofencing/application/apply_geofence_status_test.dart` | 3 tests: entered, exited, dispose |

---

## Archivos modificados (4)

| Archivo | Cambio |
|---------|--------|
| `lib/shared/events/domain_event.dart` | `ZoneEntered` +4 campos opcionales; `ZoneExited` +`circleId` opcional |
| `lib/features/geofencing/services/geofencing_service.dart` | Constructor acepta `DomainEventBus?`; 2 llamadas a `_updateUserStatusByZoneEvent` → `_bus?.publish(...)`. Método marcado `@Deprecated`. |
| `lib/features/circle/presentation/widgets/in_circle_view.dart` | `GeofencingService()` → `GeofencingService(bus: sl<DomainEventBus>())` |
| `lib/app/di/modules/geofencing_module.dart` | Registra `GeofenceStatusWriter` + `ApplyGeofenceStatus` |

---

## Criterio de done ✅

- [x] `flutter test test/contexts/geofencing/` → 3/3 verde
- [x] `flutter test test/shared/events/domain_event_bus_test.dart` → 4/4 verde
- [x] `flutter analyze --no-fatal-infos` → 0 errores nuevos, 0 warnings nuevos
- [x] `GeofencingService._detectZoneTransition` no llama `_updateUserStatusByZoneEvent`
- [x] `_updateUserStatusByZoneEvent` marcado `@Deprecated` + `// ignore: unused_element`

---

## Invariante preservado

- Check `manualOverride` en `FirestoreGeofenceStatusWriter.onZoneEntered` es idéntico al que
  tenía `_updateUserStatusByZoneEvent` — lee Firestore antes de escribir.
- `GeofencingService.suppressNextCheckOnReopen()` es método static, no afectado por el
  nuevo constructor.
- `domain_event_bus_test.dart` sigue verde sin modificar: los nuevos campos son opcionales.
