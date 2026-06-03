# Semana 5 — UI Descomposición

> **Estado:** Pendiente de inicio (2026-05-24)
> **Modelo:** Sonnet 4.6 (días 1–4) · Opus 4.7 solo si un día supera las 2h de trabajo iterativo
> **Rama base:** `main` @ `4f0caee`
> **Prerrequisito:** Soaked Tests T1–T7 PASS ✅ (2026-05-24)

---

## Objetivo

La UI consume `PresenceViewModel` y ya no contiene lógica de negocio. `in_circle_view.dart` pasa de 3107 a ≤500 líneas. El modal de selección de estado pasa a ser un widget puro sin conocimiento de prioridades.

---

## Contexto previo

| Componente | Estado actual | Líneas |
|-----------|---------------|--------|
| `in_circle_view.dart` | Widget monolítico — contiene grid de miembros, barra de estado propio, modo silencio, zonas, lógica de prioridad de estado | 3107 |
| `status_selector_overlay.dart` | Modal con lógica de pre_silent/manual/current interna | 556 |
| `PresenceViewModel` | ✅ Existe desde Sem 2 — `Stream<PresenceState>` | — |
| `contexts/identity/` | ✅ Migrado en Sem 4 Día 5 (PR #195) | — |

---

## Entregables por día

### Día 1 — Auditoría + scaffold

**Objetivo:** mapa completo de `in_circle_view.dart` antes de tocar una línea.

1. Leer el archivo completo. Catalogar cada sección con:
   - Nombre semántico propuesto
   - Líneas que ocupa
   - Dependencias que usa (servicios estáticos vs `PresenceViewModel`)
   - Si ya puede conectarse al VM o requiere adaptador
2. Identificar las 5 secciones a extraer (ver §Widgets objetivo).
3. Crear carpeta `lib/features/circle/presentation/widgets/` si no existe subdirectorio dedicado para los nuevos widgets.
4. Crear archivos vacíos de cada widget nuevo (solo clase scaffold) → permite al compilador detectar imports rotos antes de migrar lógica.
5. `flutter analyze` — cero errores nuevos.

**Criterio de done:** tabla de auditoría presentada al desarrollador. No se mueve lógica aún.

---

### Día 2 — `MemberStatusGrid`

**Objetivo:** grid de estados de los miembros del círculo extraído como widget puro.

**Responsabilidades:**
- Recibe `List<MemberPresence>` (o tipo equivalente del VM).
- Renderiza cada miembro con su emoji y nickname.
- Resalta al usuario propio.
- Sin lógica de carga, sin acceso a Firestore, sin servicios estáticos.

**Archivos afectados:**
- `lib/features/circle/presentation/widgets/member_status_grid.dart` (nuevo)
- `lib/features/circle/presentation/widgets/in_circle_view.dart` (reducción)

**Criterio:** `in_circle_view.dart` ≤2600 líneas al cierre del día.

---

### Día 3 — `MyStatusBar` + `SilentModeButton`

**Objetivo:** barra de estado propio y botón de modo silencio como widgets independientes.

**`MyStatusBar`:**
- Recibe `StatusType currentStatus`, `bool isSilentMode`.
- Muestra emoji activo + label.
- Onpress → callback hacia arriba (no decide, informa).

**`SilentModeButton`:**
- Recibe `bool isActive`, `VoidCallback onToggle`.
- Sin lógica de coordinación interna.
- La transición la decide el VM/use case.

**Archivos afectados:**
- `lib/features/circle/presentation/widgets/my_status_bar.dart` (nuevo)
- `lib/features/circle/presentation/widgets/silent_mode_button.dart` (nuevo)
- `lib/features/circle/presentation/widgets/in_circle_view.dart` (reducción)

**Criterio:** `in_circle_view.dart` ≤2000 líneas al cierre del día.

---

### Día 4 — `ZonePresenceIndicator` + `JoinRequestsBanner`

**Objetivo:** los dos widgets de contexto situacional extraídos.

**`ZonePresenceIndicator`:**
- Recibe `String? activeZoneName` (null si no hay zona activa).
- Muestra indicador visual de zona si no es null.
- No conoce el servicio de geofencing.

**`JoinRequestsBanner`:**
- Recibe `List<JoinRequest> pendingRequests`, `bool isOwner`.
- Si `!isOwner || pendingRequests.isEmpty` → `SizedBox.shrink()`.
- Callbacks: `onApprove(String uid)`, `onReject(String uid)`.
- Sin acceso directo a `CircleService`.

**Archivos afectados:**
- `lib/features/circle/presentation/widgets/zone_presence_indicator.dart` (nuevo)
- `lib/features/circle/presentation/widgets/join_requests_banner.dart` (nuevo)
- `lib/features/circle/presentation/widgets/in_circle_view.dart` (reducción)

**Criterio:** `in_circle_view.dart` ≤1200 líneas al cierre del día.

---

### Día 5 — `status_selector_overlay.dart` puro + smoke test + tag

**Objetivo:** el modal de selección de estado no conoce prioridades. `in_circle_view.dart` ≤500 líneas.

**Refactor `status_selector_overlay.dart`:**
- Input: `StatusType currentStatus`, `List<StatusType> available`, `VoidCallback(StatusType) onSelect`.
- Eliminar toda lógica de prioridad (`pre_silent`, `manual`, `current`) — esa lógica vive en `PresenceViewModel`.
- Resultado: widget puro, 100% testeable sin servicios.

**`in_circle_view.dart` como orquestador:**
- Solo conecta sub-widgets al stream del VM.
- No contiene lógica de negocio residual.
- Meta: ≤500 líneas.

**Smoke test (15 pasos mínimos):**

| Bloque | Pasos |
|--------|-------|
| A — Básico | Login ✅, Circle cargado ✅, grid de miembros visible ✅ |
| B — Modal | Abrir modal ✅, seleccionar emoji ✅, borde verde correcto ✅ |
| C — Silent Mode | Activar ✅, emoji pre-silent preservado ✅, desactivar ✅ |
| D — Background >5min | Minimizar → reabrir → modal muestra estado correcto ✅ |
| E — Background >1h | Minimizar → reabrir → seleccionar → Firestore actualiza ✅ (T5 soaked) |

**Post-smoke:**
- `flutter analyze` — 0 errores nuevos
- `flutter test` — sin regresiones
- Tag `refactor-sem5-done`
- Guardar memoria `project_refactor_sem5_done.md`

---

## Widgets objetivo

| Widget | Extraído de | Input principal | Sin estos servicios |
|--------|-------------|-----------------|---------------------|
| `MemberStatusGrid` | `in_circle_view.dart` | `List<MemberPresence>` | `CircleService`, `StatusService` |
| `MyStatusBar` | `in_circle_view.dart` | `StatusType`, `bool isSilent` | todos |
| `SilentModeButton` | `in_circle_view.dart` | `bool isActive` + callback | `SilentFunctionalityCoordinator` |
| `ZonePresenceIndicator` | `in_circle_view.dart` | `String? activeZoneName` | `GeofencingService` |
| `JoinRequestsBanner` | `in_circle_view.dart` | `List<JoinRequest>` + `bool isOwner` | `CircleService` |
| `StatusSelectorOverlay` (refactor) | `status_selector_overlay.dart` | `StatusType current` + `onSelect` | toda lógica de prioridad |

---

## Invariantes que NO cambian

- Lógica de negocio en `PresenceViewModel` (Sem 2) — no se toca.
- `navigatorKey` sigue existiendo solo para `MaterialApp`.
- `EmojiDialogActivity.kt` (modal nativo de barra superior) — no se toca en esta semana.
- `SecureCredentialService` (PR #189) — no se toca.
- Tests existentes (`flutter test`) — deben permanecer en verde al final de cada día.

---

## Riesgos

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| `in_circle_view.dart` tiene lógica acoplada difícil de separar | Alta | Día 1 de auditoría antes de cualquier extracción. No comprometerse con líneas exactas hasta ver el árbol real. |
| Los 5 widgets nuevos no cubren todo el contenido de `in_circle_view.dart` | Media | Si quedan secciones, documentarlas como `OtherInCircleContent` temporal — mejor que dejar `in_circle_view.dart` a 800 líneas sin documentar por qué. |
| `PresenceViewModel` no expone sub-state suficiente para los widgets | Media | Agregar métodos derivados al VM (getters computed) — sin tocar la state machine de Sem 2. |

---

## Métricas de éxito

| Métrica | Antes | Meta |
|---------|-------|------|
| Líneas `in_circle_view.dart` | 3107 | ≤500 |
| Líneas `status_selector_overlay.dart` | 556 | ≤200 (widget puro) |
| Widgets que acceden a servicios estáticos directamente | N | 0 (solo via callbacks/VM) |
| Tests | verde | verde (sin regresiones) |

---

## Referencia de diseño

`docs/ui/design_system.md` — tokens relevantes para los widgets extraídos:

| Token | Valor | Aplicación |
|-------|-------|------------|
| `padding-card` | 24px | `MemberStatusGrid` item padding |
| `gap-items` | 16px | gap entre items del grid |
| `radius-modal` | 24px | `StatusSelectorOverlay` container |
| `modal-in` | fade 200ms + scale 0.96→1 | animación de apertura del overlay |
| `touch-target-min` | 44px | `SilentModeButton`, `MyStatusBar` tap area |

> **Nota:** no codificar estos tokens en un archivo Dart de Design System durante Sem 5. Usarlos como referencia numérica al escribir los widgets. La codificación formal es tarea de Sem 6.
