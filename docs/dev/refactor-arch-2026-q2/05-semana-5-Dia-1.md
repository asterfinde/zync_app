# Sem 5 · Día 1 — Auditoría + Scaffold

> **Estado:** Listo para ejecutar (PA95C)
> **Confianza:** 95%
> **Modelo:** Sonnet 4.6 — suficiente. Ver §Justificación de modelo.
> **Rama:** `refactor/sem5-ui-decomposition`
> **Duración estimada:** 1.5–2h

---

## Hallazgo pre-auditoría (crítico)

`in_circle_view.dart` tiene **3107 líneas, pero solo ~1507 son código activo**.

Las líneas 1508–3107 son código legacy completamente comentado (separado por
`////////////////////////////////////////////////` en línea 1508 y `///////////////////////////////////////////////` en línea 2320). Es código muerto sin callers — la versión antigua que fue reemplazada pero nunca eliminada.

**Acción inmediata:** eliminar ese bloque antes de hacer cualquier auditoría. Reduce el archivo de 3107 → ~1507 líneas antes de extraer un solo widget.

---

## Paso 0 — Prerequisito: árbol limpio

```
git status          # debe estar limpio
git checkout -b refactor/sem5-ui-decomposition
```

---

## Paso 1 — Eliminar bloque de código muerto

**Qué:** líneas 1501–3107 (bloque legacy comentado + `StringExtension` de solo una función).

**Por qué es seguro:**
- Todo el contenido de esas líneas empieza con `//`
- El separador `////////////////////////////////////////////////` en línea 1508 marca explícitamente el inicio del legacy
- `StringExtension.capitalize()` (línea 1500-1505) es la única línea activa en esa zona — verificar con grep si tiene callers; si no los tiene, también se elimina

```bash
grep -rn "\.capitalize()" lib/ --include="*.dart"
```

Si tiene callers: mantener solo la extensión, eliminar el resto.
Si no tiene callers: eliminar todo desde la línea 1500 hasta el final.

**Criterio:** `flutter analyze` → 0 errores nuevos tras la eliminación.

---

## Paso 2 — Auditoría del archivo activo (~1507 líneas)

Leer el archivo completo y catalogar cada sección. Tabla de referencia con lo ya relevado:

| Sección | Líneas aprox | Descripción | Extractable como widget? |
|---------|-------------|-------------|--------------------------|
| Design tokens | 34–101 | `_AppColors` + `_AppTextStyles` | ✅ → `lib/shared/theme/` (Sem 6) |
| Declaración de widget | 103–110 | `InCircleView` + `ConsumerStatefulWidget` | Keeper |
| Variables de estado | 112–150 | Caches, subscriptions, flags, services | Keeper (orquestador) |
| `initState()` | 151–227 | 6 pasos: cache → listeners → background refresh → geofencing → NativeBridge sync → join requests | Keeper |
| `didUpdateWidget` + `dispose` | 229–262 | Cancelación de subscriptions + save to cache | Keeper |
| Geofencing monitoring | 264–295 | `_startGeofencingMonitoring()`, `_stopGeofencingMonitoring()` | Keeper |
| `_loadLastKnownStatusId` | 297–314 | Lee SharedPreferences para fallback del modal | Keeper |
| `_loadPredefinedEmojis` | 317–338 | Llama a `EmojiService.getAllEmojisForCircle()` | Keeper |
| Cache methods | 340–419 | `_loadFromCache`, `_refreshDataInBackground`, `_saveToCache` | Keeper |
| `_listenToStatusChanges` | 422–470 | Listener Firestore → `_memberDataCache` | Keeper → PresenceRepository (Sem 6) |
| `_parseMemberData` + `_hasChanged` | 472–616 | **Lógica de negocio** — 7 casos de prioridad de emoji/zona | ⚠️ Keeper por ahora — candidato a ViewModel en Sem 6 |
| `build()` → Header | ~618–680 | Logo "Zync" + nickname usuario + botón Ajustes | ✅ → `InCircleHeader` |
| `build()` → CircleInfoCard | ~680–760 | Código de invitación + nombre del círculo + miembros count | ✅ → `CircleInfoCard` |
| `build()` → MemberGrid | ~760–870 | Lista de miembros con emoji + nickname + SOS | ✅ → `MemberStatusGrid` |
| `build()` → JoinRequestsBanner | ~870–900 | Lista de solicitudes pendientes (solo para owner) | ✅ → `JoinRequestsBanner` |
| `_confirmAndActivateSilentMode` | 900–967 | Dialog de confirmación + coordinación de activación | ✅ → parte de `SilentModeButton` |
| `_buildFooterButton` | 969–1046 | Row con Modo Silencio + botón OK | ✅ → `InCircleFooter` |
| Helper methods | 1048–1499 | `_getCurrentUserNickname`, `_getSortedMembers`, `_getAllMemberNicknames`, etc. | Parcial → ViewModel |

**Anomalías a reportar (no corregir en Día 1):**
- Línea 636: `const Text('Zync', ...)` — texto legacy, debería ser 'NunaKin' o el nombre del círculo
- Línea 165: `print('⏳ ...')` — usar `debugPrint()` o `log()`
- Múltiples `print()` activos violando CLAUDE.md §5 — catalogar cantidad

---

## Paso 3 — Crear archivos scaffold

Crear en `lib/features/circle/presentation/widgets/`:

```
in_circle_header.dart
circle_info_card.dart
member_status_grid.dart
join_requests_banner.dart
silent_mode_button.dart
in_circle_footer.dart
```

Formato de cada scaffold:

```dart
// lib/features/circle/presentation/widgets/member_status_grid.dart
import 'package:flutter/material.dart';

/// Extrae la grilla de miembros de InCircleView.
/// TODO(sem5-dia2): implementar — ver in_circle_view.dart líneas ~760-870
class MemberStatusGrid extends StatelessWidget {
  const MemberStatusGrid({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

**No importar nada que no exista aún.** El scaffold solo declara la clase.

---

## Paso 4 — `flutter analyze` + commit

```bash
flutter analyze
# Esperar: 0 errores nuevos (puede haber warnings previos del repo)

git add lib/features/circle/presentation/widgets/
git add lib/features/circle/presentation/widgets/in_circle_view.dart
git commit -m "refactor(circle): remove dead legacy code + scaffold Sem5 widgets"
```

---

## Criterio de done

- [ ] `in_circle_view.dart` ≤ 1510 líneas (bloque comentado eliminado)
- [ ] Tabla de auditoría completa con líneas exactas por sección
- [ ] 6 archivos scaffold creados
- [ ] `flutter analyze` → 0 errores nuevos
- [ ] Anomalías catalogadas y reportadas al desarrollador (sin corregir)
- [ ] Commit limpio en `refactor/sem5-ui-decomposition`

---

## Justificación de modelo

**Sonnet 4.6 es suficiente para Día 1.** Las tareas son:

1. Eliminar texto comentado (no hay razonamiento sobre lógica)
2. Leer y catalogar secciones conocidas
3. Crear 6 clases scaffold vacías

**Cuándo usar Opus 4.7 en Sem 5:**

| Día | Tarea | ¿Opus? |
|-----|-------|--------|
| 1 | Auditoría + scaffold | ❌ Sonnet suficiente |
| 2 | Extraer `MemberStatusGrid` | ❌ Sonnet suficiente |
| 3 | Extraer `MyStatusBar` + `SilentModeButton` | ❌ Sonnet suficiente |
| 4 | Extraer `ZonePresenceIndicator` + `JoinRequestsBanner` | ❌ Sonnet suficiente |
| 5 | Refactor `status_selector_overlay` (556 líneas, lógica de prioridad compleja) | ✅ Considerar Opus si hay decisiones de diseño sobre dónde vive la lógica de prioridad |

El único caso que podría justificar Opus en Sem 5 es el Día 5, donde hay una decisión arquitectónica: la lógica de prioridad `pre_silent/manual/current` en `status_selector_overlay.dart` debe moverse al `PresenceViewModel` de Sem 2 — eso requiere entender la interfaz del VM y los casos edge de la state machine. Si ese análisis dura más de 30 min iterando con Sonnet, cambiar a Opus.

---

## Cuándo se aplica el Design System en código Dart

| Semana | Acción |
|--------|--------|
| Sem 5 | Referencia numérica al escribir los widgets (tokens de spacing, radius, animation) |
| Sem 6 | Crear `lib/shared/theme/app_theme.dart` con las constantes de `_AppColors` + `_AppTextStyles` formalizadas. Reemplazar las definiciones privadas dispersas (actualmente hay una por archivo) con imports a ese archivo central. |
| Sem 10 | Verificación final: el código usa las constantes del DS; `design_system.md` coincide con los valores en `app_theme.dart`. |

El momento exacto en Sem 6 es post-hardening de tests, cuando el código es estable y el riesgo de introducir regressions es bajo.
