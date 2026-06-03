# NunaKin · Design System

> Una app de estado para tus círculos cercanos. Sin feed, sin likes, sin desconocidos.

NunaKin (anteriormente conocida como **Zync** en algunas pantallas legacy) ayuda a las personas a compartir cómo están —Casa, Trabajo, Camino, S.O.S— con un círculo privado de gente que les importa, en un solo toque y sin tener que escribir un mensaje.

Este Design System formaliza por primera vez los tokens, componentes y reglas visuales que la app ya usa de hecho. Fue reconstruido desde:

- 7 capturas de la app móvil (splash, login, registro, círculo, modales de estado, S.O.S).
- Código Dart canónico del logo (`ZyncLogoPainter`) — proporciones y color de marca exactos.
- Guía de tono establecida en el deck de lanzamiento.

> **Heads-up**: el código fuente Flutter completo no fue compartido; los tokens de tipografía, espaciado y elevación son **inferidos a partir de las pantallas y de las HIG de iOS**. Si más adelante se adjunta el repo, se puede calibrar al pixel.

---

## Index

| Archivo | Para qué |
|---|---|
| `colors_and_type.css` | Tokens CSS (color, type, spacing, radii, shadow, motion) |
| `assets/logo-mark.svg` | Logo molecular reconstruido desde el `CustomPainter` Dart |
| `assets/logo-lockup.svg` | Logo + wordmark "NunaKin" |
| `tokens/` | Pruebas visuales de cada categoría de token |
| `components/` | Recreaciones HTML/CSS de los componentes core |
| `iconography/` | Guía de iconos (SF Symbols) y mapeo a Material |
| `voice_and_tone.md` | Guía de copywriting en español |
| `preview/` | Cards individuales que pueblan la pestaña Design System |
| `SKILL.md` | Skill para usar este DS desde Claude Code |

---

## Content fundamentals (voz y tono)

Idioma: **español**. El tono es **cálido y humano** — la app trata de cuidado mutuo, no de productividad.

**Reglas:**

1. **Tono neutral, segunda persona singular**. "Aún no estás en un círculo", "¿Qué te gustaría hacer?". No usar formas rioplatenses ("vos", "tenés", "hacés"). Excepción: copy de error/sistema puede ser neutro impersonal ("No se pudo enviar").
2. **Frases cortas, una idea por línea.** Los headers son una pregunta o una afirmación, no un slogan ("Bienvenido", "Crea tu Cuenta", "Aún no estás en un círculo").
3. **Verbos en imperativo amable** para CTAs primarios: "Crear un Círculo", "Iniciar Sesión", "Únete con un código de invitación". Capitalizada solo la primera letra y los sustantivos clave.
4. **Sin emoji en UI chrome**. Los emoji aparecen SOLO dentro de los estados (Casa 🏠, Trabajo 🏢, S.O.S 🚨) — son contenido, no decoración.
5. **Sin signos de exclamación de marketing**. La app no celebra; informa. "Justo Ahora" no es "¡Justo ahora!".
6. **Etiquetas cortas en estados**: una palabra cuando se pueda (Casa, Trabajo, Camino, Comiendo). Dos palabras max ("No molestar", "S.O.S").
7. **Códigos de invitación en MAYÚSCULAS y mono**: `WRNLXM`, `CLASE26`. Siempre 6 caracteres alfanuméricos, sin separadores.
8. **Datos personales mínimos**. La copy refuerza la privacidad: "tu apodo público", "tu círculo", "los demás saben que estás bien".

**Microcopy ejemplos canon:**

| Contexto | Copy |
|---|---|
| CTA primario login | "Iniciar Sesión" |
| CTA primario registro | "Crear Cuenta" |
| Empty state círculo | "Aún no estás en un círculo" / "¿Qué te gustaría hacer?" |
| Acción destructiva | "Cerrar Sesión" |
| Estado especial | "S.O.S — Mantén presionado para enviar" |
| Toggle de foco | "Modo Silencio" |
| Confirmación | "OK" (no "Aceptar", no "Confirmar") |

---

## Visual foundations

### Color

- **Negro absoluto** (`#000`) como canvas. Sin gradientes generales; sin off-blacks.
- **Una marca, una sola** — el mint `#1CE8A1` es **simultáneamente** marca, acento, success y CTA primario. No competimos con ningún otro verde.
- **Rojo solo para S.O.S y sign-out**. Su aparición es noticia.
- Saturación ≤ 0.02 en grises (whites tintados con verde imperceptible para que armonicen con el mint).

### Tipografía

Sistema operativo nativo: **SF Pro Display/Text** en iOS, **Roboto** en Android. En web usamos el stack `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, …`. **No cargamos webfonts** en móvil — la performance lo agradece.

Jerarquía clara, **pocos tamaños**: display 32 / h1 28 / h2 22 / h3 18 / body 16 / meta 14 / micro 12. Pesos: 400/500/600/700.

**Mono** (SF Mono / Menlo) **solo para códigos de invitación, build numbers, debug tags**. Letter-spacing aumentado (`0.08em–0.16em`) para legibilidad de caracteres únicos.

### Espaciado

Grid de **4pt**. Tokens: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64. El padding default de cards es **24px**, gap entre items **16px**, gap entre secciones **32px**. Touch targets nunca menores a **44px** (HIG).

### Radios

Suaves pero presentes. **12** para inputs, **16** para botones, **20** para cards, **24** para modales/action cards grandes, **999** para chips/pills. **Nunca radios mixtos** en un mismo componente.

### Imagery / fondo

Sin imágenes de stock, sin gradientes en fondos generales. La app es **literal**: lo que ves es lo que hay. La única "imagen" recurrente es el logo molecular en mint sobre negro (splash, header de círculo).

### Animación

- **Splash breathing**: scale 0.95 ↔ 1.05, easeInOut, 2s, reverse infinito (canónico, viene del Dart).
- **Fade in** de pantallas: 1s, easeIn.
- **Hover/press en web**: opacity → 0.85, duración 120ms, easing standard.
- **Press en móvil**: scale 0.98, duración 100ms.
- **Modal in**: fade 200ms + scale 0.96→1 con `--nk-ease-emph`.
- **Sin bounces**, sin spring animations vistosas. La app es serena.

### Bordes y elevación

Sobre negro puro, las **shadows pierden eficacia** — usamos **bordes de 1px** (`rgba(255,255,255,0.10)`) como definidor primario de superficies. Las shadows aparecen solo en modales (z elevado) y en el glow del CTA primario (`0 0 24px rgba(28,232,161,0.16)`). Sin "left-border accent cards" — no es nuestro vocabulario.

### Estados de interacción

| Estado | Botón primario (mint) | Botón ghost (outline mint) | Card / Cell |
|---|---|---|---|
| Default | Bg mint, fg `#001` | Border mint, fg mint | Bg surface-2, border line |
| Hover (web) | Bg mint-soft | Bg mint @ 8% | Bg surface-3 |
| Pressed | Scale 0.98, bg mint-deep | Bg mint @ 16% | Bg surface-4 |
| Disabled | Bg mint @ 40%, fg `#001` @ 60% | Border line, fg fg-disabled | — |
| Focus (kbd) | 2px ring mint @ 60% offset 2 | mismo | mismo |

### Layout rules

- **Status bar siempre visible** en pantallas full-screen móvil.
- **CTAs primarios al fondo**, full-width con padding lateral 24px y bottom 24px (safe area + 24).
- En modales con grilla de opciones (estado), el botón S.O.S va **fuera** de la grilla, abajo, full-width — es jerárquicamente distinto.
- **Header de pantalla**: título a la izquierda, acción primaria/secundaria a la derecha. Z-index siempre por encima del scroll.

### Iconografía

**SF Symbols** como sistema canónico (iOS-first product). En Android se mapean a Material Icons equivalentes. Los iconos van **outlined** por default, **filled** solo cuando representan estado activo. Tamaño base **24px**, color hereda `currentColor` del texto adyacente. Nunca decorativos: cada icono comunica algo accionable o de estado. Ver `iconography/README.md` para el mapeo.

**Emoji** se usan **solo** dentro de los selectores de estado, donde son el contenido principal — no son chrome.

---

## Iteración

Este DS está construido a partir de capturas y código del logo. Para llevarlo a producción al 100%, lo ideal es:

1. Adjuntar el repo Flutter (`zync_app`) para extraer tokens reales y nombres de componentes.
2. Confirmar la fuente real en cada plataforma (asumimos system fonts).
3. Auditar que las pantallas legacy "Zync" se renombren progresivamente a NunaKin.

> 💬 **Para el reviewer**: revisá las cards en la pestaña **Design System**. Cualquier token que no encaje, comentamelo y lo ajusto.
