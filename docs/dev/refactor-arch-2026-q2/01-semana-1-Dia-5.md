# Sem 1 — Día 5: Contrato compartido Dart↔Kotlin + cierre de semana

**Rama:** `refactor/sem1-shared-contract`

**Modelo:** Sonnet 4.6

**Base:** main → `fdda98b` (cierre smoke test + PRs #150 + #151)

---

## Contexto real del código

| Elemento | Estado |
|----------|--------|
| `lib/platform/persistence/storage_keys.dart` | ✅ Existe — 12 claves Flutter + 2 dinámicas |
| `lib/platform/persistence/native_keys.dart` | ❌ No existe — crear hoy |
| `android/.../SharedKeys.kt` | ❌ No existe — crear hoy |
| `lib/contexts/presence/domain/value_objects/status_id.dart` | ❌ No existe — crear hoy |
| `android/.../StatusIds.kt` | ❌ No existe — crear hoy |
| Literales en Dart (ruta crítica) | `'current_status_id'`, `'manual_status_id'`, `'pre_silent_status_id'`, `'is_silent_mode_active'`, `'suppress_next_geofence_check'` — siguen como strings |
| Literales en Kotlin (ruta crítica) | `"flutter.current_status_id"`, `"flutter.is_silent_mode_active"`, `"flutter.pre_silent_status_id"`, `"flutter.suppress_next_geofence_check"` — siguen como strings |
| `flutter test` | 42/42 ✅ |
| `flutter analyze` | 394 issues (baseline — 0 nuevos) |

**Nota sobre `in_circle_view.dart:785`:** lee `is_silent_mode_active` de `silentPrefs` (namespace `zync_silent_mode`, Kotlin nativo) — **NO** del namespace Flutter. Ese literal queda fuera de NativeSharedKeys. Se resuelve en Sem 3 (bridge nativo).

---

## Archivos del Día 5

| Acción | Archivo |
|--------|---------|
| Crear | `lib/platform/persistence/native_keys.dart` |
| Crear | `android/app/src/main/kotlin/com/datainfers/zync/SharedKeys.kt` |
| Crear | `lib/contexts/presence/domain/value_objects/status_id.dart` |
| Crear | `android/app/src/main/kotlin/com/datainfers/zync/StatusIds.kt` |
| Modificar | `lib/core/services/status_service.dart` |
| Modificar | `lib/core/services/silent_functionality_coordinator.dart` |
| Modificar | `lib/main.dart` |
| Modificar | `lib/features/circle/presentation/widgets/in_circle_view.dart` |
| Modificar | `android/app/src/main/kotlin/com/datainfers/zync/EmojiDialogActivity.kt` |
| Modificar | `android/app/src/main/kotlin/com/datainfers/zync/MainActivity.kt` |
| Modificar | `android/app/src/main/kotlin/com/datainfers/zync/StatusUpdateWorker.kt` |

---

## Tarea 1 — lib/platform/persistence/native_keys.dart (CREAR)

```dart
/// Claves de SharedPreferences que cruzan la frontera Dart↔Kotlin.
///
/// IMPORTANTE: cualquier cambio aquí debe reflejarse en
/// android/app/src/main/kotlin/com/datainfers/zync/SharedKeys.kt
///
/// Las claves escritas desde Flutter se almacenan en disco con prefijo
/// "flutter." (comportamiento del plugin). Usar [flutter] para construir
/// la clave con prefijo cuando Kotlin las lee directamente.
abstract final class NativeSharedKeys {
  static const flutterPrefix = 'flutter.';

  // ── Presence ──────────────────────────────────────────────────────────────
  /// Estado de presencia activo. Escrito por: StatusService (Dart) y
  /// StatusUpdateWorker.kt (Kotlin). Leído por: EmojiDialogActivity.kt.
  static const currentStatusId = 'current_status_id';

  /// Último estado seleccionado manualmente. Solo escrito por StatusService.
  /// Leído por: SilentCoordinator, InCircleView.
  static const manualStatusId = 'manual_status_id';

  /// Snapshot del estado antes de entrar a Silent Mode.
  /// Escrito por: SilentCoordinator. Leído por: InCircleView.
  /// Eliminado por: MainActivity al desactivar Silent Mode.
  static const preSilentStatusId = 'pre_silent_status_id';

  /// Flag de Silent Mode activo (namespace Flutter).
  /// Escrito por: SilentCoordinator. Leído/eliminado por: MainActivity.
  /// NOTA: coexiste con zync_silent_mode.is_silent_mode_active en Kotlin — Sem 3.
  static const isSilentModeActive = 'is_silent_mode_active';

  // ── Geofence ───────────────────────────────────────────────────────────────
  /// Flag para suprimir el siguiente check de geofence en cold start.
  /// Escrito por: StatusUpdateWorker.kt. Leído/eliminado por: main.dart.
  static const suppressNextGeofenceCheck = 'suppress_next_geofence_check';

  // ── Native cache (Flutter → Kotlin) ───────────────────────────────────────
  /// JSON de emojis predefinidos. Escrito por EmojiCacheService.
  /// Leído por EmojiDialogActivity.
  static const predefinedEmojis = 'predefined_emojis';

  /// JSON de tipos de zona configurados. Escrito por EmojiCacheService.
  /// Leído por EmojiDialogActivity.
  static const configuredZoneTypes = 'configured_zone_types';

  /// Retorna la clave con prefijo Flutter (como la almacena el plugin en disco).
  static String flutter(String key) => '$flutterPrefix$key';

  NativeSharedKeys._();
}
```

---

## Tarea 2 — android/.../SharedKeys.kt (CREAR)

```kotlin
package com.datainfers.zync

/**
 * Claves de SharedPreferences que cruzan la frontera Dart↔Kotlin.
 *
 * IMPORTANTE: cualquier cambio aquí debe reflejarse en
 * lib/platform/persistence/native_keys.dart
 *
 * Las claves escritas desde Flutter se almacenan con prefijo "flutter."
 * (comportamiento del plugin). Usar [flutter] para construir la clave
 * con prefijo al leer desde Kotlin.
 */
object SharedKeys {
    private const val FLUTTER_PREFIX = "flutter."

    // Presence
    const val CURRENT_STATUS_ID = "current_status_id"
    const val MANUAL_STATUS_ID = "manual_status_id"
    const val PRE_SILENT_STATUS_ID = "pre_silent_status_id"
    const val IS_SILENT_MODE_ACTIVE = "is_silent_mode_active"

    // Geofence
    const val SUPPRESS_NEXT_GEOFENCE_CHECK = "suppress_next_geofence_check"

    // Native cache
    const val PREDEFINED_EMOJIS = "predefined_emojis"
    const val CONFIGURED_ZONE_TYPES = "configured_zone_types"

    fun flutter(key: String): String = "$FLUTTER_PREFIX$key"
}
```

---

## Tarea 3 — lib/contexts/presence/domain/value_objects/status_id.dart (CREAR)

```dart
/// IDs canónicos de estado de presencia.
///
/// Fuente única de verdad para Dart. Mirror en StatusIds.kt.
/// Los IDs deben coincidir exactamente con los valores en Firestore.
abstract final class StatusIds {
  static const fine            = 'fine';
  static const home            = 'home';
  static const school          = 'school';
  static const work            = 'work';
  static const university      = 'university';
  static const sos             = 'sos';
  static const doNotDisturb    = 'do_not_disturb';
  static const publicTransport = 'public_transport';

  /// Estados que no pueden seleccionarse manualmente cuando hay
  /// una zona de ese tipo configurada en el círculo.
  static const Set<String> blockedManualSelectionIfZoneConfigured = {
    home, school, work, university,
  };

  StatusIds._();
}
```

---

## Tarea 4 — android/.../StatusIds.kt (CREAR)

```kotlin
package com.datainfers.zync

/**
 * IDs canónicos de estado de presencia.
 *
 * IMPORTANTE: cualquier cambio aquí debe reflejarse en
 * lib/contexts/presence/domain/value_objects/status_id.dart
 *
 * Los IDs deben coincidir exactamente con los valores en Firestore.
 */
object StatusIds {
    const val FINE             = "fine"
    const val HOME             = "home"
    const val SCHOOL           = "school"
    const val WORK             = "work"
    const val UNIVERSITY       = "university"
    const val SOS              = "sos"
    const val DO_NOT_DISTURB   = "do_not_disturb"
    const val PUBLIC_TRANSPORT = "public_transport"
}
```

---

## Tarea 5 — Reemplazo de literales en archivos de alto impacto

### 5.1 lib/core/services/status_service.dart

**Import a agregar:**
```dart
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/platform/persistence/native_keys.dart';
```

**Reemplazos:**

| Literal actual | Reemplazar por |
|----------------|---------------|
| `'home'` (en `_blockedZoneStatusIds`) | `StatusIds.home` |
| `'school'` (en `_blockedZoneStatusIds`) | `StatusIds.school` |
| `'work'` (en `_blockedZoneStatusIds`) | `StatusIds.work` |
| `'university'` (en `_blockedZoneStatusIds`) | `StatusIds.university` |
| `newStatus.id != 'fine'` (línea ~157) | `newStatus.id != StatusIds.fine` |
| `newStatus.id == 'sos'` (línea ~163) | `newStatus.id == StatusIds.sos` |
| `prefs.setString('current_status_id', ...)` (línea ~243) | `prefs.setString(NativeSharedKeys.currentStatusId, ...)` |
| `prefs.setString('manual_status_id', ...)` (línea ~254) | `prefs.setString(NativeSharedKeys.manualStatusId, ...)` |

**Nota:** Los literales en comments tipo `// ... flutter.current_status_id ...` se dejan como están.

---

### 5.2 lib/core/services/silent_functionality_coordinator.dart

**Import a agregar:**
```dart
import 'package:nunakin_app/platform/persistence/native_keys.dart';
```

**Reemplazos:**

| Literal actual | Reemplazar por |
|----------------|---------------|
| `prefs.getString('manual_status_id')` (línea ~139) | `prefs.getString(NativeSharedKeys.manualStatusId)` |
| `prefs.setString('pre_silent_status_id', manualId)` (línea ~141) | `prefs.setString(NativeSharedKeys.preSilentStatusId, manualId)` |
| `prefs.setBool('is_silent_mode_active', true)` (línea ~144) | `prefs.setBool(NativeSharedKeys.isSilentModeActive, true)` |

---

### 5.3 lib/main.dart

**Import a agregar:**
```dart
import 'package:nunakin_app/platform/persistence/native_keys.dart';
```

**Reemplazos:**

| Literal actual | Reemplazar por |
|----------------|---------------|
| `flutterPrefs.getBool('suppress_next_geofence_check')` (línea ~62) | `flutterPrefs.getBool(NativeSharedKeys.suppressNextGeofenceCheck)` |
| `flutterPrefs.remove('suppress_next_geofence_check')` (línea ~64) | `flutterPrefs.remove(NativeSharedKeys.suppressNextGeofenceCheck)` |

---

### 5.4 lib/features/circle/presentation/widgets/in_circle_view.dart

**Import a agregar:**
```dart
import 'package:nunakin_app/platform/persistence/native_keys.dart';
```

**Reemplazos:**

| Literal actual | Reemplazar por |
|----------------|---------------|
| `silentPrefs.getBool('is_silent_mode_active')` (línea ~785) | Sin cambio — esta clave pertenece al namespace Kotlin `zync_silent_mode`, no a Flutter SharedPrefs. Resuelto en Sem 3. |
| `prefs.getString('pre_silent_status_id')` (línea ~787) | `prefs.getString(NativeSharedKeys.preSilentStatusId)` |

**Solo 1 reemplazo activo en este archivo.**

---

### 5.5 android/.../EmojiDialogActivity.kt

**Import a agregar:**
```kotlin
// (en el mismo package — no requiere import adicional)
```

**Reemplazos:**

| Literal actual | Reemplazar por |
|----------------|---------------|
| `flutterPrefs.getString("flutter.current_status_id", null)` (línea ~115) | `flutterPrefs.getString(SharedKeys.flutter(SharedKeys.CURRENT_STATUS_ID), null)` |

---

### 5.6 android/.../MainActivity.kt

**Reemplazos:**

| Literal actual | Línea aprox. | Reemplazar por |
|----------------|-------------|----------------|
| `silentPrefs.getBoolean("is_silent_mode_active", false)` | ~114 | `silentPrefs.getBoolean(SharedKeys.IS_SILENT_MODE_ACTIVE, false)` |
| `.putBoolean("is_silent_mode_active", false)` (deactivate) | ~140 | `.putBoolean(SharedKeys.IS_SILENT_MODE_ACTIVE, false)` |
| `.remove("flutter.is_silent_mode_active")` | ~148 | `.remove(SharedKeys.flutter(SharedKeys.IS_SILENT_MODE_ACTIVE))` |
| `.remove("flutter.pre_silent_status_id")` | ~149 | `.remove(SharedKeys.flutter(SharedKeys.PRE_SILENT_STATUS_ID))` |
| `.putBoolean("is_silent_mode_active", true)` (activate) | ~534 | `.putBoolean(SharedKeys.IS_SILENT_MODE_ACTIVE, true)` |
| `.putBoolean("is_silent_mode_active", false)` (deactivate channel) | ~548 | `.putBoolean(SharedKeys.IS_SILENT_MODE_ACTIVE, false)` |
| `.remove("flutter.is_silent_mode_active")` | ~552 | `.remove(SharedKeys.flutter(SharedKeys.IS_SILENT_MODE_ACTIVE))` |
| `.remove("flutter.pre_silent_status_id")` | ~553 | `.remove(SharedKeys.flutter(SharedKeys.PRE_SILENT_STATUS_ID))` |

**Nota:** Los literales en líneas comentadas (~234, ~258) se dejan como están.

---

### 5.7 android/.../StatusUpdateWorker.kt

**Reemplazos:**

| Literal actual | Línea aprox. | Reemplazar por |
|----------------|-------------|----------------|
| `.putBoolean("flutter.suppress_next_geofence_check", true)` | ~148 | `.putBoolean(SharedKeys.flutter(SharedKeys.SUPPRESS_NEXT_GEOFENCE_CHECK), true)` |
| `.putString("flutter.current_status_id", statusType)` | ~149 | `.putString(SharedKeys.flutter(SharedKeys.CURRENT_STATUS_ID), statusType)` |

---

## Tarea 6 — Tests

No se crean tests nuevos. Los cambios son renaming de literales por constantes — el comportamiento en runtime es idéntico. Verificar que la suite existente sigue en verde:

```
flutter test
```

Esperado: **42/42 ✅**

---

## Tarea 7 — Cierre de semana

1. **Smoke test** en device físico: ciclo Normal → Silent → Normal con backgrounding ≥10 min (mismos 6 pasos del smoke test pre-Día 5).
2. **Tag:** `git tag refactor-sem1-done` en el commit de main post-merge.
3. **Memoria de cierre:** entrada `project_refactor_sem1_done.md` en `memory/`.
4. **Borrador Sem 2:** crear `docs/dev/refactor-arch-2026-q2/02-semana-2-presence.md` como placeholder con estructura básica.

---

## Restricciones

| Regla | Razón |
|-------|-------|
| NO migrar archivos fuera de los listados | Scope acotado — literales restantes se migran en su semana |
| NO tocar `'is_silent_mode_active'` en `in_circle_view.dart:785` (silentPrefs) | Pertenece a namespace Kotlin `zync_silent_mode`, no a Flutter. Sem 3. |
| NO crear constantes para namespaces Kotlin-only (`zync_silent_mode`, `pending_status`, `worker_state`) | Esos se unifican en Sem 3 con el Native Bridge |
| NO tocar `lib/platform/bridge/` | Sem 3 |
| NO reemplazar literales en comments de código | Solo código ejecutable |

---

## Entregable

**PR:** `refactor(platform): shared Dart/Kotlin keys + StatusIds constants`

---

## Criterio de done

| # | Criterio | Verificación |
|---|----------|--------------|
| 1 | `native_keys.dart` + `SharedKeys.kt` creados y simétricos | Comparar constantes |
| 2 | `status_id.dart` + `StatusIds.kt` creados y simétricos | Comparar constantes |
| 3 | 0 literales de claves de presencia/geofence en archivos de alto-impacto | `grep -r "'current_status_id'\|'manual_status_id'\|'pre_silent_status_id'\|'is_silent_mode_active'\|'suppress_next_geofence_check'" lib/core lib/main.dart lib/features/circle` |
| 4 | 0 literales en Kotlin de alto-impacto | Similar grep en `.kt` afectados |
| 5 | `flutter test` 42/42 ✅ | `flutter test` |
| 6 | `flutter analyze` sin warnings nuevos vs baseline | `flutter analyze` |
| 7 | Smoke test 6/6 pasos ✅ | Dispositivo físico |
| 8 | Tag `refactor-sem1-done` en main | `git tag -l` |
| 9 | Memoria de cierre guardada | Archivo en `memory/` |
| 10 | Borrador `02-semana-2-presence.md` publicado | Archivo en `docs/dev/refactor-arch-2026-q2/` |

---

## Riesgos

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| Import de `native_keys.dart` o `status_id.dart` roto por path incorrecto | Baja | Verificar con `flutter analyze` antes de correr tests |
| `SharedKeys` no importado en un archivo Kotlin → error de compilación | Baja | Hacer build Android antes del PR |
| Literal en comment reemplazado accidentalmente | Muy baja | Revisar diff antes de commitear |
| `in_circle_view.dart:785` — `silentPrefs` reemplazado por error con NativeSharedKeys | Media | Explícitamente documentado: ese literal NO se toca |
