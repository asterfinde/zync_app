# Semana 7 — Flujos no refactorizados

> **Estado:** 🔲 Pendiente de inicio (2026-06-09)
> **Modelo:** Sonnet 4.6 (PR A, B, D) · Opus para PR C (486 líneas, lógica compleja)
> **Rama base:** `main` @ `1a0edaf` (post PR #217)
> **Prerrequisito:** Sem 6a ✅ · `main` verde · PR #218 mergeado

---

## Objetivo

Eliminar el 40% del código legado que el refactor de Sems 1–6 no alcanzó. Cuatro archivos/call sites que aún usan `StatusService` estático, `StatusType.fallbackPredefined` hardcodeado o keys de SharedPrefs como strings literales. Al cierre de Sem 7, el frente Flutter ↔ Kotlin para selección de estado estará completamente alineado a la arquitectura nueva.

---

## Contexto previo

Las Sems 1–6 construyeron la infraestructura nueva (state machine, use cases, KvStore, NativeBridge). Sem 7 cierra el círculo migrado los últimos callers que todavía bypasean esa infraestructura.

| Síntoma | Causa raíz | Donde vive |
|---------|-----------|------------|
| Cold-start race: `configured_zone_types = []` en Firestore | `EmojiCacheService.syncEmojisToNativeCache()` en `main.dart` se llama antes de que Auth garantice el círculo | `lib/main.dart` ~línea 108 |
| Modal de barra de estado (BN) ignora emojis personalizados del círculo | `notification_status_selector.dart` usa `StatusType.fallbackPredefined` hardcodeado en lugar del repositorio | `lib/widgets/notification_status_selector.dart` |
| Quick Actions y home screen widget actualizan estado por vía estática | `quick_actions_handler.dart` y `widget_service.dart` llaman a `StatusService.updateUserStatus()` directo | `lib/quick_actions/` · `lib/widgets/` |
| `EmojiDialogActivity.kt` depende de un string hardcodeado | Lee `"flutter.configured_zone_types"` literal — desincronizable si `StorageKeys` cambia | `android/app/src/main/kotlin/.../EmojiDialogActivity.kt` ~línea 260 |

---

## Infraestructura disponible (ya existe)

| Componente | Ubicación | Uso en Sem 7 |
|-----------|-----------|-------------|
| `SetManualStatus` | `lib/app/di/modules/presence_module.dart` (registrado como Factory) | PR B, PR C |
| `EmojiService.getAllEmojisForCircle(circleId)` | `lib/core/services/emoji_service.dart` | PR C |
| `StorageKeys.configuredZoneTypes` | `lib/platform/persistence/native_keys.dart` | PR D |
| `KvStore` / `sl<KvStore>()` | `lib/app/di/modules/platform_module.dart` | PR B, PR D |
| `InCircleView.initState()` → ya llama `EmojiCacheService.syncEmojisToNativeCache()` con Auth garantizado | `lib/features/circle/presentation/widgets/in_circle_view.dart` | PR A (justificación de seguridad) |

---

## Entregables — 4 PRs en orden

### PR A — `main.dart`: eliminar sync prematuro

**Riesgo:** bajo  
**Modelo:** Sonnet 4.6  
**Duración estimada:** 30 min  
**Doc detalle:** [`07-semana-7-Dia-1.md`](07-semana-7-Dia-1.md)

Eliminar la línea `EmojiCacheService.syncEmojisToNativeCache()` en `main.dart` (~línea 108). Esta llamada se ejecuta durante la inicialización de la app antes de que Auth complete, lo que puede escribir `configured_zone_types = []` al nativo antes de conocer el círculo del usuario.

`InCircleView.initState()` ya llama al mismo sync con Auth y círculo garantizados — la cobertura no se pierde.

---

### PR B — `quick_actions` + `widget_service` → `SetManualStatus`

**Riesgo:** bajo  
**Modelo:** Sonnet 4.6  
**Duración estimada:** 1h  
**Doc detalle:** [`07-semana-7-Dia-2.md`](07-semana-7-Dia-2.md)

Dos archivos que llaman a `StatusService.updateUserStatus()` directamente:
- `lib/quick_actions/quick_actions_handler.dart`
- `lib/widgets/widget_service.dart`

Reemplazar por `sl<SetManualStatus>().call(statusId, userId, circleId)`. El `circleId` está disponible en `KvStore` via `StorageKeys.circleId`.

---

### PR C — `notification_status_selector.dart` (Opus)

**Riesgo:** medio  
**Modelo:** Opus 4.7  
**Duración estimada:** 2–3h  
**Doc detalle:** [`07-semana-7-Dia-3.md`](07-semana-7-Dia-3.md)

486 líneas. Dos cambios estructurales:
1. Reemplazar `StatusType.fallbackPredefined` por `EmojiService.getAllEmojisForCircle(circleId)` — el modal de BN mostrará los emojis reales del círculo.
2. Reemplazar `StatusService.updateUserStatus()` por `sl<SetManualStatus>()`.

Este es el PR más complejo de la semana: el modal de notificaciones tiene estado propio, lógica de BN vs Silent, y se muestra desde código nativo. **Requiere smoke test en device antes de PR D.**

---

### PR D — `EmojiDialogActivity.kt`: string → StorageKeys

**Riesgo:** bajo  
**Modelo:** Sonnet 4.6  
**Duración estimada:** 30 min  
**Doc detalle:** [`07-semana-7-Dia-4.md`](07-semana-7-Dia-4.md)

En `EmojiDialogActivity.kt` ~línea 260: reemplazar el string literal `"flutter.configured_zone_types"` por la constante equivalente. Kotlin no puede importar `StorageKeys.kt` directamente si vive en el módulo Flutter, por lo que se define una `companion object` local o un `object` Kotlin con la misma constante — con un comentario de contrato que señala la fuente de verdad.

**Prerrequisito:** PR C mergeado y verificado en device.

---

## Orden de ejecución

```
PR A (bajo, 30min) → PR B (bajo, 1h) → PR C (medio, Opus, 2-3h)
  → smoke test en device → PR D (bajo, 30min)
```

PR A y PR B pueden ejecutarse en la misma sesión. PR C en sesión separada con Opus. PR D solo tras smoke test de PR C.

---

## Smoke test de cierre (post PR C, pre PR D)

| Paso | Escenario | Criterio |
|------|-----------|----------|
| 1 | Login → Circle visible | ✅ |
| 2 | Enviar notificación BN a otro miembro | Modal de barra muestra emojis del círculo (no hardcodeados) |
| 3 | Seleccionar emoji desde barra | Estado actualiza en Firestore + miembros ven cambio |
| 4 | Quick Action desde home screen widget | Estado actualiza correctamente |
| 5 | Activar Silent Mode → enviar BN | Modal BN sigue funcionando en Silent |
| 6 | Cold start desde notificación BN | `configured_zone_types` cargado correctamente (no vacío) |

---

## Criterio de done — Sem 7

- [ ] `grep -rn "StatusService.updateUserStatus" lib/` → 0 resultados en quick_actions y widget_service
- [ ] `grep -rn "fallbackPredefined" lib/` → 0 resultados en notification_status_selector
- [ ] `grep -rn "flutter.configured_zone_types" android/` → 0 literales (reemplazado por constante)
- [ ] `EmojiCacheService.syncEmojisToNativeCache()` eliminado de `main.dart`
- [ ] Smoke test 6 pasos PASS en device físico
- [ ] `flutter analyze` → 0 errores nuevos
- [ ] Tests existentes: 93+ en verde
- [ ] Tag `refactor-sem7-done`
- [ ] `00-plan-unificado.md` actualizado

---

## Métricas objetivo

| Métrica | Antes | Meta |
|---------|-------|------|
| Callers de `StatusService.updateUserStatus` en quick_actions/widget | 2 | 0 |
| Usos de `StatusType.fallbackPredefined` | 1 | 0 |
| Keys de SharedPrefs como strings literales en Kotlin | 1 (`"flutter.configured_zone_types"`) | 0 |
| Cold-start race `configured_zone_types = []` | Reproducible | No reproducible |

---

## Invariantes que NO cambian

- `StatusService.updateUserStatus` en `status_service.dart` — sigue existiendo (otros callers fuera de scope).
- Lógica de BN/Silent en `notification_status_selector.dart` — solo se cambia la fuente de emojis y el caller de update.
- `EmojiDialogActivity.kt` — solo se cambia el string de key, sin tocar la lógica de renderizado.
- Tests existentes (93) — deben permanecer en verde al final de cada PR.

---

## Lo que NO se toca (scope de Sem 8)

- `GeofencingService` → `ZoneRepository` BC — Sem 8.
- `DomainEventBus` integración completa — Sem 8.
- Tests E2E en device físico (Normal→Silent→Normal con GPS real) — Sem 7 smoke test cubre el happy path; E2E formal es Sem 10.

---

## Referencias

- Plan unificado: [`00-plan-unificado.md`](00-plan-unificado.md) §3.7
- Infraestructura reutilizada: `lib/app/di/modules/presence_module.dart`, `lib/platform/persistence/native_keys.dart`
- Memoria sesión: `memory/project_session_20260609_sem7_plan.md`
