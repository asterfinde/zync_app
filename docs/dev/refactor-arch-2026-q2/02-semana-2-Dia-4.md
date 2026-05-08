# Sem 2 - Día 4 — `ExitSilentMode` + `RaiseSOS` + `FirestorePresencePublisher`

**Rama:** `refactor/sem2-use-cases-exit-sos-publisher`

**PR:** `refactor(presence): ExitSilentMode + RaiseSOS + FirestorePresencePublisher`

**Fecha planificada:** 2026-05-22 (jueves)

**Base:** PR #157 → commit `e00aed1`

---

## Contexto

Día 4 de Sem 2. Se completan las 4 transiciones del state machine de presencia con los use cases `ExitSilentMode` y `RaiseSOS`, y se extrae la lógica de escritura Firestore en `FirestorePresencePublisher`. Todo el código nuevo es aditivo — **no se invoca desde producción**. `StatusService` y `SilentFunctionalityCoordinator` siguen siendo la ruta activa.

**Estado del repo al inicio:**
- `lib/contexts/presence/application/use_cases/set_manual_status.dart` ✅ (Día 3)
- `lib/contexts/presence/application/use_cases/enter_silent_mode.dart` ✅ (Día 3)
- `lib/contexts/presence/application/ports/presence_publisher.dart` ✅ (Día 3)
- `test/helpers/presence/fake_presence_repository.dart` ✅ (Día 3)
- `test/helpers/presence/fake_presence_publisher.dart` ✅ (Día 3)

---

## Tarea 1 — `lib/contexts/presence/application/use_cases/exit_silent_mode.dart`

Use case para salir del Modo Silencio. Restaura el `preSilentId` como estado activo.

**Garantías:**
- Idempotencia: si ya está en `Normal`, devuelve `Success` sin escribir.
- `restoredId` usa `SilentMode.preSilentId`; para cualquier otro estado fallback a `StatusIds.fine`.
- postcondición implícita: si `saveState` devuelve `Success`, SharedPrefs quedará en `Normal`.

---

## Tarea 2 — `lib/contexts/presence/application/use_cases/raise_sos.dart`

Use case para activar SOS. Captura `visibleStatusId` del estado actual como `previousId`
y publica a Firestore vía `PresencePublisher`.

**Garantías:**
- `previousId` = `currentState().visibleStatusId` (no un campo manual).
- Si `saveState` falla → no llama al publisher.
- Funciona correctamente desde cualquier estado previo (Normal, SilentMode, etc.).

---

## Tarea 3 — `lib/contexts/presence/infrastructure/firestore_presence_publisher.dart`

Extrae la lógica de batch write de `StatusService.updateUserStatus`.

**Nota sobre zona context:** `StatusService.updateUserStatus` lee el estado anterior de Firestore
para preservar `zoneId`, `zoneName`, `customEmoji` al hacer override dentro de una zona.
Esta lógica se completa en Sem 4 (Geofencing context). En Sem 2, la publicación omite
los campos de zona (el campo queda null). Es aceptable porque el publisher no se usa en producción.

**En Sem 2, esta clase no se invoca desde código de producción.**

---

## Tarea 4 — Tests

### `test/contexts/presence/application/exit_silent_mode_test.dart` — 3 tests

| # | Escenario | Verificación |
|---|-----------|-------------|
| 1 | `SilentMode(preSilentId: 'work')` → `Normal(currentId: 'work', lastManualId: 'work')` | `repo.lastSavedState` campos correctos |
| 2 | Idempotencia: ya en `Normal` → `Success` sin escribir | `repo.saveCallCount == 0` |
| 3 | `Contract.requires` lanza cuando `userId` está vacío | `throwsA(isA<ContractViolation>())` |

### `test/contexts/presence/application/raise_sos_test.dart` — 7 tests

| # | Escenario | Verificación |
|---|-----------|-------------|
| 1 | `previousId` captura `visibleStatusId` del estado actual | `sos.previousId == 'school'` |
| 2 | Invoca `publisher.publish` con `SOSActive` | `publisher.publishCallCount == 1`, `lastPublishedState is SOSActive` |
| 3 | Si `saveState` falla → no llama al publisher | `publisher.publishCallCount == 0` |
| 4 | Desde `SilentMode` → `previousId = preSilentId` | `sos.previousId == 'work'` |
| 5 | `Contract.requires` lanza cuando `userId` está vacío | `throwsA(isA<ContractViolation>())` |
| 6 | `Contract.requires` lanza cuando `circleId` está vacío | `throwsA(isA<ContractViolation>())` |
| 7 | Desde cold start → `previousId = StatusIds.fine` | `sos.previousId == 'fine'` |

### `test/contexts/presence/infrastructure/firestore_presence_publisher_test.dart` — SKIP

⚠️ **Pendiente:** requiere `fake_cloud_firestore` en `dev_dependencies`.

```yaml
dev_dependencies:
  fake_cloud_firestore: ^3.0.4   # verificar última versión compatible
```

Escenarios a implementar una vez agregada la dependencia:
1. `Normal` state → batch escribe en `circles/{id}/memberStatus/{uid}` y `statusEvents/` sin `coordinates`.
2. `SOSActive` state → batch incluye `coordinates` en ambas escrituras.

---

## Archivos afectados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `lib/contexts/presence/application/use_cases/exit_silent_mode.dart` | Nuevo | Use case |
| `lib/contexts/presence/application/use_cases/raise_sos.dart` | Nuevo | Use case |
| `lib/contexts/presence/infrastructure/firestore_presence_publisher.dart` | Nuevo | Adaptador de salida Firestore |
| `test/contexts/presence/application/exit_silent_mode_test.dart` | Nuevo | 3 tests |
| `test/contexts/presence/application/raise_sos_test.dart` | Nuevo | 7 tests |
| `test/contexts/presence/infrastructure/firestore_presence_publisher_test.dart` | Nuevo | 1 skip (pendiente dep) |

**Archivos de producción activa no modificados:** `StatusService`, `SilentFunctionalityCoordinator`,
`presence_module.dart` (placeholder intacto — se puebla en Día 5), ningún widget.

---

## Criterios de done

| Criterio | Estado |
|----------|--------|
| `ExitSilentMode` y `RaiseSOS` cubren las 4 transiciones del state machine | ✅ |
| `FirestorePresencePublisher` compila sin warnings | ✅ |
| Use cases no importan nada de `features/`, `core/services/`, ni `platform/` | ✅ |
| 10 tests en verde (3 + 7) + 1 skip documentado | ✅ |
| `flutter analyze` 394 issues (baseline, 0 nuevos) | ✅ |

---

**Pendiente para Sem 2 Día 5:** `PresenceViewModel` + DI wiring + cierre de semana.

**Deuda registrada:** `fake_cloud_firestore` en dev_dependencies para activar tests de `FirestorePresencePublisher`.
