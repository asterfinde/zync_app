# TEST_SUITE.md — Suite de Tests Automatizados

> Documento de referencia para los tests unitarios e integración del refactor arquitectónico (Sem 1–6).
> No cubre pruebas manuales en dispositivo — ver `TEST_PLAN_2.md` para eso.
> Última actualización: 2026-05-27 (Sem 6 Hardening)

---

## Cómo correr los tests

```powershell
# Suite completa
flutter test --no-pub

# Un archivo específico (recomendado durante desarrollo)
flutter test test/contexts/presence/presence_integration_test.dart --no-pub

# Un contexto completo
flutter test test/contexts/presence/ --no-pub
```

> **Nota Windows:** `result_test.dart` falla esporádicamente con `SocketException`
> cuando el sistema tiene muchos procesos Dart/Flutter activos (socket exhaustion).
> No es un bug del código — cerrar worktrees y procesos colgados lo resuelve.

---

## Resumen

| Métrica | Valor |
|---------|-------|
| Archivos de test | 23 |
| Archivos helper (fakes) | 2 |
| Tests totales | ~147 |
| Skips | 1 (`fake_cloud_firestore` pendiente) |
| Cobertura de dominio (presence + circle) | ~80% |

---

## Mapa por contexto

### `test/contexts/presence/` — 7 archivos

| Archivo | Qué cubre |
|---------|-----------|
| `domain/presence_state_test.dart` | Sealed states: `Normal`, `SilentMode`, `BackgroundNotificationActive`, `SOSActive`. `visibleStatusId` por estado. |
| `application/enter_silent_mode_test.dart` | Transiciones a `SilentMode`. Idempotencia. `preSilentId` desde `lastManualId` o `currentId`. DbC `userId` vacío. |
| `application/exit_silent_mode_test.dart` | Restaura `Normal` desde `SilentMode`. Idempotencia. DbC `userId` vacío. |
| `application/raise_sos_test.dart` | Activa `SOSActive` con coordenadas GPS. Publisher invocado. |
| `application/set_manual_status_test.dart` | Actualiza `Normal`. `lastManualId` se preserva. Publisher invocado. |
| `infrastructure/shared_prefs_presence_repository_test.dart` | Persistencia en `KvStore`. Lectura/escritura por estado. |
| `infrastructure/firestore_presence_publisher_test.dart` | Publisher escribe a Firestore (fake). |
| `presence_integration_test.dart` | **Ciclos completos:** Normal→Manual→Silent→Normal→SOS (T1+T3). BN→Silent→Normal (T2 y T2b). VM emite estados correctamente. |

---

### `test/contexts/circle/` — 5 archivos

| Archivo | Qué cubre |
|---------|-----------|
| `domain/membership_state_test.dart` | `UserNoCircle`, `UserPendingRequest`, `UserInCircle`. Transiciones válidas. |
| `application/join_circle_test.dart` | Flujo de unirse a un círculo. Validaciones de estado previo. |
| `application/approve_join_request_test.dart` | Solo el owner aprueba. Rechaza si no es owner. |
| `application/delete_account_test.dart` | Limpia circle + presence + session al eliminar cuenta. |
| `application/circle_view_model_test.dart` | VM emite `MembershipState` correcto. Stream reactivo. |

---

### `test/contexts/identity/` — 2 archivos

| Archivo | Qué cubre |
|---------|-----------|
| `domain/session_state_test.dart` | `Anonymous` vs `Authenticated`. Campos `uid` y `email`. |
| `application/identity_view_model_test.dart` | VM emite cambios de sesión. Logout limpia estado. |

---

### `test/contexts/geofencing/` — 1 archivo

| Archivo | Qué cubre |
|---------|-----------|
| `application/apply_geofence_status_test.dart` | `ZoneEntered` → `SetAutomaticStatus`. `ZoneExited` → restaura estado previo. |

---

### `test/platform/` — 4 archivos

| Archivo | Qué cubre |
|---------|-----------|
| `bridge/android_native_bridge_test.dart` | Canal único `nunakin/bridge`. `invoke()` con `NativeCommand`. Eventos recibidos. |
| `bridge/native_command_test.dart` | Sealed commands: `ActivateSilentMode`, `DeactivateSilentMode`, `GetCurrentLocation`, `SetUserSession`. |
| `bridge/native_event_test.dart` | Sealed events: `StatusUpdatedFromNotification`, `SilentDeactivatedByUser`, `GeofenceEntered`, `GeofenceExited`. |
| `persistence/shared_prefs_kv_store_test.dart` | `KvStore`: read/write/delete por tipo. `StorageKeys` tipados. |

---

### `test/shared/` — 3 archivos

| Archivo | Qué cubre |
|---------|-----------|
| `result_test.dart` | `Success`/`Failure`. Subtypes (`NetworkFailure`, `AuthFailure`, etc.). ⚠️ Flaky por SocketException en Windows. |
| `contract_test.dart` | `Contract.requires` / `Contract.ensures`. `ContractViolation` lanzado en debug. No-op en release. |
| `events/domain_event_bus_test.dart` | `DomainEventBus`: `publish` / `subscribe`. Broadcast a múltiples suscriptores. `dispose` cierra stream. |

---

### `test/helpers/` — 2 archivos (no son tests)

| Archivo | Qué provee |
|---------|-----------|
| `presence/fake_presence_repository.dart` | `FakePresenceRepository`: in-memory, `setState()`, `saveStateOverride`, contadores. |
| `presence/fake_presence_publisher.dart` | `FakePresencePublisher`: registra llamadas, verifica que publisher fue invocado N veces. |

---

## Lo que NO tiene tests aún

| Área | Estado | Cuándo |
|------|--------|--------|
| `StatusService` (legacy) | Sin tests — servicio estático con 9+ callers | Sem 7: se migra a use cases |
| `notification_status_selector` | Sin tests | Sem 7 |
| `quick_actions_handler` | Sin tests | Sem 7 |
| `widget_service` | Sin tests | Sem 7 |
| `EmojiDialogActivity.kt` | Kotlin — requiere tests Android | Sem 8/9 |
| `SilentFunctionalityCoordinator` | Coordinador legacy | Sem 7 al migrar |
| Flujos UI end-to-end | Requieren device/emulador + `integration_test/` con Firebase real | Sem 10 |
| Restauración BN post-Silent | Comportamiento documentado en T2: BN se limpia, no se restaura. Deuda explícita. | Sem 7 |

---

## Flujos críticos cubiertos por tests automatizados

| ID | Flujo | Archivo |
|----|-------|---------|
| T1 | Normal → Manual → Silent → Normal → SOS | `presence_integration_test.dart` |
| T2 | BN activo → Silent → Normal(fine) | `presence_integration_test.dart` |
| T3 | RaiseSOS con GPS | `presence_integration_test.dart` + `raise_sos_test.dart` |
| G1 | ZoneEntered → SetAutomaticStatus | `apply_geofence_status_test.dart` |
| C1 | JoinCircle → ApproveJoinRequest | `join_circle_test.dart` + `approve_join_request_test.dart` |

---

## Relación con TEST_PLAN_2.md

`TEST_PLAN_2.md` cubre pruebas **manuales en dispositivo físico** (lo que el usuario ve en pantalla).
Este documento cubre pruebas **automatizadas** (lo que el compilador verifica).

Ambos son necesarios — los tests automatizados no reemplazan el smoke test en device antes de cada PR.
