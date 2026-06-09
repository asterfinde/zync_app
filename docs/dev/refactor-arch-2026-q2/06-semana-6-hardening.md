# Semana 6 — Hardening (parcial)

> **Estado:** ✅ Completa (2026-05-27)
> **Modelo:** Sonnet 4.6
> **Rama:** `refactor/sem6-hardening`
> **Tag:** `refactor-sem6-done` @ `9fcfda2`
> **PR:** #201
> **Prerrequisito:** `refactor-sem5-done` @ `d2cb2a7`

---

## Objetivo

Consolidar el núcleo refactorizado (Sems 1–5) antes de expandir hacia los contextos pendientes. No se agrega funcionalidad nueva. El sprint cierra con código muerto eliminado, tests de integración del core en verde y documentación canónica actualizada.

---

## Contexto previo

| Semana | Estado al iniciar Sem 6 |
|--------|------------------------|
| 1 Cimientos | ✅ KvStore + Contract + DI modular |
| 2 Presence | ✅ State machine + PresenceViewModel + 87 tests |
| 3 Native Bridge | ✅ BridgeRouter + USE_LEGACY_BRIDGE=false |
| 4 Identity + Circle | ✅ contexts/identity migrado, ApplyGeofenceStatus |
| 5 UI descomposición | ✅ in_circle_view ≤800 líneas, 6 widgets extraídos |

**Deuda conocida al entrar en Sem 6:**
- `setOfflineStatus` / `clearOfflineStatus` en `status_service.dart` son no-ops sin callers — shims muertos del bridge viejo.
- Tests de integración BN+Silent no existían en `integration_test/`.
- `docs/dev/architecture.md` desactualizado (describía pre-refactor).
- No había baseline de performance documentado.

---

## Entregables

### E1 — Eliminar shims muertos

**Archivos:** `lib/core/services/status_service.dart`

`setOfflineStatus()` y `clearOfflineStatus()` eran wrappers que actualizaban Firestore con estado offline/online. El NativeBridge unificado (Sem 3) absorbió ese comportamiento; los métodos quedaron como no-ops sin callers activos.

**Acción:** eliminar ambos métodos y sus referencias en imports. **`StatusService.updateUserStatus` NO se toca** — tiene 9+ callers activos, se migra en Sem 7.

**Criterio:** `grep -rn "setOfflineStatus\|clearOfflineStatus" lib/` → 0 resultados.

---

### E2 — Tests de integración BN+Silent

**Archivo:** `test/contexts/presence/presence_integration_test.dart`

6 tests que cubren las transiciones críticas del core refactorizado:

| Test | Escenario |
|------|-----------|
| T2.1 | Normal → BN → Normal |
| T2.2 | Silent → BN durante Silent → exit BN → Silent preservado |
| T2.3 | BN manual sobreescribe BN de notificación |
| T2.4 | Exit Silent → recupera estado pre-Silent |
| T2.5 | SOS interrumpe Silent → exit SOS → Silent restaurado |
| T2.6 | Idempotencia: entrar a Silent dos veces → no duplica transición |

**Criterio:** `flutter test test/contexts/presence/presence_integration_test.dart --no-pub` → 6/6 PASS.

---

### E3 — Documentación canónica

Tres archivos actualizados / creados:

| Archivo | Contenido |
|---------|-----------|
| `docs/dev/architecture.md` | Diagrama de BCs completos (Sems 1–5), reglas de imports, contratos entre capas |
| `docs/dev/TEST_SUITE.md` | Inventario completo de tests: unitarios, integración, manuales. Estado por semana |
| `docs/dev/refactor-arch-2026-q2/00-plan-unificado.md` | Tabla de avance actualizada + sección Sem 6a agregada |

---

### E4 — Performance baseline

**Archivo:** `docs/dev/performance-baseline.md`

Mediciones en modo debug (Pixel 6, Android 13):

| Métrica | Valor debug | Referencia |
|---------|------------|------------|
| Cold start (launch → circle visible) | 6304 ms | `mvp-baseline-20260506` no medido |
| Login (tap "Ingresar" → circle visible) | 7276 ms | — |
| App resume tras 5 min background | < 800 ms | — |

**Nota:** valores en modo debug son 3–5× más lentos que release. Sirven como baseline relativo para detectar regresiones entre semanas.

---

## Resultado real vs. planificado

| Entregable | Planificado | Ejecutado |
|-----------|-------------|-----------|
| E1 shims eliminados | ✅ | ✅ |
| E2 tests BN+Silent 6/6 | ✅ | ✅ |
| E3 docs canónica | ✅ | ✅ |
| E4 performance baseline | ✅ | ✅ |
| Tests E2E transición Normal→Silent→Normal | 🔲 | ➡️ Diferido a Sem 7 smoke test |

Los tests E2E en dispositivo físico para el flujo completo Normal→Silent→Normal se diferieron: requieren GPS real y >1h de background, incompatibles con el ritmo de la semana. Se verifican como parte del smoke test de cierre de Sem 7.

---

## Métricas de cierre

| Métrica | Valor |
|---------|-------|
| Tests unitarios/integración | 87 previos + 6 nuevos = **93 en verde** |
| Archivos modificados | 5 (status_service + 3 docs + presence_integration_test) |
| PRs | #201 |
| Shims eliminados | 2 (`setOfflineStatus`, `clearOfflineStatus`) |

---

## Lo que NO se tocó

- `StatusService.updateUserStatus` — 9+ callers activos. Se migra en Sem 7.
- Tests E2E en device físico — diferidos a Sem 7.
- Cualquier contexto de UI — alcance exclusivo de Sem 6a.

---

## Próximo: Sem 6a — Design System

Ver [`06a-semana-6a-design-system.md`](06a-semana-6a-design-system.md).
