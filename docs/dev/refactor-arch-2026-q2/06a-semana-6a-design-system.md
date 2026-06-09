# Semana 6a — Design System

> **Estado:** ✅ Completa (2026-06-09, extendida con DS v2.0 Minimalist)
> **Modelo:** Sonnet 4.6
> **Rama base:** `refactor/sem6a-design-system` → `style/*` (capas DS v2)
> **Tag:** `refactor-sem6-done` incluye Sem 6a (no tag separado)
> **PRs:** #203 (Sem 6a formal) · #205–#218 (DS v2.0 Minimalist por capas)
> **Prerrequisito:** `refactor-sem6-done` ✅ · `main` verde

---

## Objetivo

Codificar formalmente los tokens de diseño como constantes Dart, extraer componentes base reutilizables, y hacer una pasada visual completa en todas las pantallas activas de la app usando el sistema unificado. Sin lógica de negocio. Sin cambios a ViewModels ni servicios.

---

## Contexto previo

Al cerrar Sem 6, los valores visuales (colores, espaciados, radios) existían como:
- Clases privadas `_AppColors` / `_AppTextStyles` duplicadas en cada archivo.
- Constantes hardcodeadas (`const Color(0xFF1EE9A4)`, `BorderRadius.circular(16)`) sin nombre semántico.
- Sin componentes base reutilizables — cada pantalla construía sus propios inputs, dialogs y headers desde cero.

**UFV del DS:** `docs/ui/NunaKin Design System.md` → siempre prevalece sobre cualquier HTML o mockup.

---

## Fase 1 — Sem 6a Formal: tokens + migración inicial (PR #203)

### Entregable

`lib/app/theme/design_tokens.dart` — tokens tipados canónicos:

```dart
// Colores
NkColors.canvas        // fondo principal
NkColors.mint          // acento primario
NkColors.onMint        // texto sobre mint
NkColors.danger        // acciones destructivas
NkColors.fgSub / fgMuted / fgHint
NkColors.surface2 / surface3 / surface4

// Espaciado
NkSpacing.xs / s / m / l / xl

// Radios
NkRadius.forButton / forInput / forCard

// Tipografía
NkTextStyle.h1 / h2 / h3 / meta / caption
```

### 13 archivos migrados en PR #203

| Archivo |
|---------|
| `silent_mode_button.dart` |
| `in_circle_footer.dart` |
| `in_circle_view.dart` |
| `member_status_grid.dart` |
| `create_circle_view.dart` |
| `join_circle_view.dart` |
| `no_circle_view.dart` |
| `pending_request_view.dart` |
| `emoji_management_page.dart` |
| `status_selector_overlay.dart` |
| `emoji_modal.dart` |
| `splash_screen.dart` |
| `zones_page.dart` |

**Resultado:** 0 errores, 0 warnings. Solo 286 `info` preexistentes (print, withOpacity deprecated).

---

## Fase 2 — DS v2.0 Minimalist: capas 1–3c

El DS v2.0 es una pasada visual completa sobre la UI existente aplicando la estética minimalist definida en `docs/ui/NunaKin Design System.md`. Se ejecutó en 4 capas.

---

### Capa 1 — `design_tokens.dart` versionado (PR #208)

Revisión y consolidación de `lib/app/theme/design_tokens.dart`:
- Tokens de espaciado extendidos (`NkSpacing.s5`, `xs3`).
- `NkColors.mintSoft(double alpha)` — función para mint con opacidad variable.
- `NkRadius.forInput` unificado.
- `NkTextStyle` alineado con especificaciones `docs/ui/NunaKin Design System.md`.

---

### Capa 2 — `NunaKinTextField` (PR #209)

Nuevo componente base en `lib/core/widgets/nunakin_text_field.dart`:
- Campo de texto con estética DS (fondo `surfaceCard`, borde mint en focus `mintSoft(0.08)`).
- Parámetros: `controller`, `label`, `hint`, `obscureText`, `suffixIcon`, `onSubmitted`.
- **No expone `onChanged`** — el caller usa `controller.addListener()`.
- Migración de `auth_final_page.dart` a `NunaKinTextField` incluida en mismo PR.

**Fix PR #211:** focused background era constante `surfaceCard` — se corrigió a `_isFocused ? mintSoft(0.08) : surfaceCard`.

---

### Capa 3a — `NoCircleView` DS (PRs #210, #212–#213)

- Glass cards para "Crear círculo" / "Unirse a círculo" (`color: const Color(0x18FFFFFF)`).
- Header con botón "Cerrar sesión" alineado al DS.
- `NkAppHeader` extraído como widget base en `lib/core/widgets/nk_app_header.dart` (PR #215) — reutilizado por `NoCircleView` y `auth_final_page`.

---

### Capa 3b — `auth_final_page.dart` DS (parte de PR #209 + PR #215)

- Títulos 28px bold, labels `fgSub`, floating label mint.
- Bordes 0.5px (unfocused) / 1px (focused).
- Auth field background `0x18FFFFFF` (alineado con card color).
- NunaKin brand en header de autenticación.

---

### Capa 3c — `InCircleView` + sub-widgets DS (PRs #216–#217)

Aplicación de DS Capa 3c a `in_circle_view.dart` y sus widgets extraídos en Sem 5:

| Widget | Cambio principal |
|--------|-----------------|
| `in_circle_view.dart` | Colores, fonts, bordes alineados a NkTokens |
| `member_status_grid.dart` | Cards compactas, avatar + nickname con tokens |
| `circle_info_card.dart` | Info card con borde mint suave |
| `in_circle_header.dart` | Botón "Ajustes" outlined #052A1D |
| `in_circle_footer.dart` | Botones iguales, padding NkSpacing |
| `join_requests_banner.dart` | Color y spacing via tokens |

Verificado en dispositivo físico: PASS visual ✅.

---

### Capa adicional — `NkDialog` unificado (PR #218)

Nuevo componente en `lib/core/widgets/nk_dialog.dart`:
- `NkDialog.confirm(context, ...)` — confirmación con acciones Cancelar/Confirmar.
- `NkDialog.inform(context, ...)` — informativo con una acción + soporte de `contentWidget`.
- `confirmDestructive: true` → botón confirm en `NkColors.danger`.
- **UFV de estilo:** modal "Silencio" en `in_circle_footer.dart`.

5 call sites migrados: `in_circle_footer`, `no_circle_view`, `zones_page`, `zone_selection_not_allowed_dialog`, `settings_page`.

3 call sites dejados intactos (parciales): `auth_wrapper` (ícono en título), `zone_form` (GPS requerido con ícono), `settings_page._showReauthDialog` (StatefulBuilder + TextField de contraseña).

---

## Resultado final

| Métrica | Antes (Sem 6 cierre) | Después (Sem 6a cierre) |
|---------|----------------------|------------------------|
| Archivos con colores hardcodeados | ~18 | 0 (solo valores literales en tokens) |
| Clases privadas `_AppColors`/`_AppTextStyles` | 5 duplicadas | 0 (todas reemplazadas por NkTokens) |
| Componentes base reutilizables | 0 | 4 (`NunaKinTextField`, `NkAppHeader`, `NkDialog`, `SilentModeButton`) |
| PRs DS | — | #203, #205–#218 |
| Tests | 93 verde | 93 verde (sin regresiones) |

---

## Invariantes que NO cambiaron

- Lógica de negocio en ViewModels y use cases — intacta.
- `EmojiDialogActivity.kt` — sin cambios visuales.
- `status_service.dart` — sin cambios (scope de Sem 7).
- Esquema de navegación — sin cambios.

---

## Próximo: Sem 7 — Flujos no refactorizados

Ver [`07-semana-7-flujos-legacy.md`](07-semana-7-flujos-legacy.md).
