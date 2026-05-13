# Sem 1 - Día 1 — Estructura de carpetas + branch**

**Rama(s):** refactor/sem1-scaffold + refactor/sem1-scaffold-delta (delta el mismo día)

**PRs:** #144 ✅ + #145 ✅

**Fecha:** 2026-05-06

**Base:** tag mvp-baseline-20260506 → commit 9c3518e

**main post-Día 1:** f42a400

---

**PR #144 — refactor(scaffold): structure for bounded contexts + arch docs**

**Commit:** 3136525 — 44 archivos, +1058 líneas, −1 línea

---

## Tarea 1 — Estructura de carpetas con .gitkeep

Se crearon carpetas vacías para los 5 bounded contexts + infraestructura transversal:

```
lib/
├── app/.gitkeep
├── contexts/
│   ├── .gitkeep
│   ├── circle/
│   │   ├── .gitkeep
│   │   ├── application/{ports,use_cases}/.gitkeep
│   │   ├── domain/.gitkeep
│   │   ├── infrastructure/.gitkeep
│   │   └── presentation/.gitkeep           ← reemplazado en PR #145
│   ├── geofencing/  (misma estructura)
│   ├── identity/    (misma estructura)
│   ├── notifications/ (misma estructura)
│   └── presence/    (misma estructura)
├── platform/
│   ├── bridge/.gitkeep
│   └── persistence/.gitkeep
└── shared/.gitkeep
```

**Decisión ejecutada:** `invariants/` y `policies/` no se incluyeron — invariantes viven como métodos de entidad (`canX()`, `assertValid()`); `policies/` se crea solo cuando emerja una regla reutilizable fuera de las entidades.

---

## Tarea 2 — lib/contexts/README.md

Documentó las reglas de imports embebidas en el contrato del proyecto:

| Capa | Puede importar | Prohibido |
|------|----------------|-----------|
| `domain/` | Solo `shared/` | Todo lo demás |
| `application/` | `domain/`, `shared/` | `infrastructure/`, `presentation/`, Flutter SDK |
| `infrastructure/` | `domain/`, `application/ports/`, `shared/`, `platform/`, paquetes externos | `presentation/` directamente |
| `presentation/` | `application/use_cases/`, `domain/`, `shared/`, Flutter SDK | `infrastructure/`, `platform/` directamente |

**Regla crítica documentada:** `platform/` solo accesible desde `infrastructure/`. Ejemplo de uso correcto vs. incorrecto incluido con código real.

---

## Tarea 3 — analysis_options.yaml

Extendido `exclude` para cubrir `scripts/**` completo y `backups/**`.

Tres reglas documentadas como TODO (no activadas — surfacean violaciones pre-existentes):

| Regla | Activación | Violaciones estimadas |
|-------|------------|----------------------|
| `avoid_print` | Sem 6 (limpieza de `debugPrint()`) | ~300 |
| `always_use_package_imports` | Sem 2 (al poblar `lib/contexts/`) | ~285 |
| `directives_ordering` | Sem 2 (mismo momento) | — |

---

## Tarea 4 — Docs de arquitectura

| Archivo | Descripción |
|---------|-------------|
| `docs/dev/refactor-arch-2026-q2/00-plan-unificado.md` | Plan completo 6 semanas (v1.0) |
| `docs/dev/refactor-arch-2026-q2/01-semana-1-cimientos.md` | Detalle día a día Sem 1 |

**Criterios cumplidos:**

- ✅ `flutter analyze` verde (394 issues — todos pre-existentes del baseline)
- ✅ `flutter test` verde (suite existente sin tocar)
- ✅ Cero cambios funcionales

---

**PR #145 — refactor(scaffold): split presentation/ + add shared/events + update arch docs**

**Commit:** 938d5bd — 14 archivos, +165 líneas, −35 líneas

---

## Refinamiento 1 — Split de presentation/

`presentation/.gitkeep` reemplazado por `presentation/widgets/` + `presentation/view_models/` en los 5 BCs:

```
contexts/<bc>/presentation/
├── widgets/.gitkeep     ← widgets atómicos reutilizables del BC
└── view_models/.gitkeep ← lógica de presentación pura (sin Flutter widgets)
```

**Decisión ejecutada:** Las pantallas completas que orquestan múltiples BCs van en `app/screens/` (Sem 5) — no dentro de ningún BC individual.

---

## Refinamiento 2 — lib/shared/events/.gitkeep

Placeholder creado para `DomainEventBus` (se puebla en Sem 2).

---

## Refinamiento 3 — lib/contexts/README.md actualizado

Agregadas tres secciones:

1. **Regla `platform/` solo desde `infrastructure/`** — con ejemplo de código (puerto en `application/ports/` vs. import directo incorrecto).

2. **Comunicación entre contextos vía DomainEventBus** — tabla de flujos activos en Nunakin:

| Publicador | Evento | Suscriptor | Acción |
|------------|--------|------------|--------|
| geofencing | `ZoneEntered` / `ZoneExited` | presence | `SetAutomaticStatus` |
| identity | `SessionEnded` | circle, presence, geofencing, notifications | cleanup |
| notifications | `NotificationStatusSelected` | presence | `SetPresenceFromNotification` |

3. **Convención de imports** — package imports obligatorios, relative imports prohibidos fuera del propio directorio.

---

## Refinamiento 4 — Docs actualizados

| Archivo | Actualización |
|---------|---------------|
| `00-plan-unificado.md` | §2.2 corregido (estructura real) + §2.5 nuevo (DomainEventBus con código sketch completo y tabla inter-BC) |
| `01-semana-1-cimientos.md` | Sincronizado con la estructura real ejecutada |

---

## Estructura en main al cierre del Día 1

```
lib/
├── app/.gitkeep
├── contexts/
│   ├── README.md
│   └── {identity,circle,presence,geofencing,notifications}/
│       ├── domain/.gitkeep
│       ├── application/{ports,use_cases}/.gitkeep
│       ├── infrastructure/.gitkeep
│       └── presentation/{widgets,view_models}/.gitkeep
├── platform/
│   ├── bridge/.gitkeep
│   └── persistence/.gitkeep
└── shared/
    ├── .gitkeep
    └── events/.gitkeep

docs/dev/refactor-arch-2026-q2/
├── 00-plan-unificado.md   (§2.2 + §2.5 DomainEventBus)
└── 01-semana-1-cimientos.md

android/ → sin cambios
lib/ (código existente) → sin cambios
```

---

## Criterios de done — verificados ✅

| Criterio | Estado |
|----------|--------|
| `flutter analyze` verde (solo warnings pre-existentes) | ✅ |
| `flutter test` verde | ✅ |
| Estructura visible en el árbol del repo | ✅ |
| `lib/contexts/README.md` con reglas completas | ✅ |
| `analysis_options.yaml` con TODOs documentados | ✅ |
| Docs de arquitectura publicados | ✅ |
| Cero cambios funcionales | ✅ |
| Cero archivos de código fuente modificados | ✅ |

---

**Siguiente: Día 2  Result<T> y Failure**