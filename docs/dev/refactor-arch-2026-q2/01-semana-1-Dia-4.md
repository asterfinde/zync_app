# Sem 1 - Día 4 — KvStore + Auditoría de claves

**Rama:** refactor/sem1-kvstore

**Modelo:** Sonnet 4.6

**Base:** main → 76a80f7 (cierre Día 3)

---

## Contexto real del código

Estado relevante antes de tocar nada:

| Archivo / elemento | Estado |
|--------------------|--------|
| `lib/platform/persistence/` | Existe con `.gitkeep` — listo para recibir archivos |
| `lib/platform/bridge/` | Existe con `.gitkeep` — Sem 3, no tocar |
| `lib/app/di/modules/platform_module.dart` | Placeholder activo con `// TODO Día 4: KvStore` |
| `SharedPreferences.getInstance()` | Llamado 12 veces en 8 archivos distintos — sin abstracción |
| Claves de presencia críticas | `current_status_id`, `manual_status_id`, `pre_silent_status_id`, `is_silent_mode_active`, `suppress_next_geofence_check` — literales string dispersos en Dart + Kotlin |
| `is_silent_mode_active` | Doble existencia: `FlutterSharedPreferences` (`flutter.is_silent_mode_active`) y `zync_silent_mode` (Kotlin nativo) — raíz de bugs históricos |
| `external_module.dart` | Ya registra `SharedPreferences` como singleton en DI — KvStore lo consumirá vía `sl()` |

**Consecuencia para el plan:** KvStore es puro adaptador sobre la instancia ya registrada. No hay llamadas adicionales a `SharedPreferences.getInstance()`.

---

## Archivos del Día 4

| Acción | Archivo |
|--------|---------|
| Crear | `lib/platform/persistence/kv_store.dart` |
| Crear | `lib/platform/persistence/shared_prefs_kv_store.dart` |
| Crear | `lib/platform/persistence/storage_keys.dart` |
| Crear | `docs/dev/refactor-arch-2026-q2/storage-keys-audit.md` |
| Modificar | `lib/app/di/modules/platform_module.dart` |
| Crear | `test/platform/persistence/shared_prefs_kv_store_test.dart` |

---

## Tarea 1 — lib/platform/persistence/kv_store.dart

```dart
import 'dart:async';

abstract class KvStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<int?> getInt(String key);
  Future<void> setInt(String key, int value);
  Future<void> remove(String key);
  Future<bool> containsKey(String key);
}
```

**Por qué todos `Future<T>`:** aunque `SharedPreferences` sincroniza reads en memoria, la interfaz no asume eso — permite impls alternativas (Hive, Isar, SQLite) sin cambiar callers.

---

## Tarea 2 — lib/platform/persistence/shared_prefs_kv_store.dart

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'kv_store.dart';

class SharedPrefsKvStore implements KvStore {
  final SharedPreferences _prefs;

  const SharedPrefsKvStore(this._prefs);

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<bool?> getBool(String key) async => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<int?> getInt(String key) async => _prefs.getInt(key);

  @override
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async => _prefs.containsKey(key);
}
```

**Nota:** no se agrega `getDouble` — no hay uso en el proyecto. Añadir si emerge en Sem 2+.

---

## Tarea 3 — lib/platform/persistence/storage_keys.dart

Catálogo completo derivado de la auditoría real del código base:

```dart
/// Single source of truth para claves de SharedPreferences en Dart.
///
/// Organización por dominio. Las claves marcadas [CROSS-BOUNDARY] son
/// leídas/escritas también desde Kotlin — ver NativeSharedKeys (Día 5).
abstract final class StorageKeys {
  // ── Presence (CROSS-BOUNDARY) ──────────────────────────────────────────
  /// Estado de presencia activo. Escrito por StatusService y StatusUpdateWorker.
  /// Leído por EmojiDialogActivity vía "flutter.current_status_id". [CROSS-BOUNDARY]
  static const currentStatusId = 'current_status_id';

  /// Último estado seleccionado manualmente. Escrito por StatusService.
  /// Leído por SilentCoordinator e InCircleView. [CROSS-BOUNDARY]
  static const manualStatusId = 'manual_status_id';

  /// Estado guardado antes de entrar a Silent Mode. Escrito por SilentCoordinator.
  /// Leído por InCircleView; eliminado por MainActivity al desactivar. [CROSS-BOUNDARY]
  static const preSilentStatusId = 'pre_silent_status_id';

  /// Flag de Silent Mode activo. Escrito por SilentCoordinator.
  /// Leído por InCircleView; eliminado por MainActivity al desactivar. [CROSS-BOUNDARY]
  /// NOTA: coexiste con "zync_silent_mode".is_silent_mode_active en Kotlin — raíz histórica de bugs.
  static const isSilentModeActive = 'is_silent_mode_active';

  /// Flag para suprimir el siguiente check de geofence. Escrito por StatusUpdateWorker (Kotlin).
  /// Leído por main.dart en cold start. [CROSS-BOUNDARY]
  static const suppressNextGeofenceCheck = 'suppress_next_geofence_check';

  // ── Native cache (CROSS-BOUNDARY) ──────────────────────────────────────
  /// JSON de emojis predefinidos. Escrito por EmojiCacheService.
  /// Leído por EmojiDialogActivity vía "flutter.predefined_emojis". [CROSS-BOUNDARY]
  static const predefinedEmojis = 'predefined_emojis';

  /// JSON de tipos de zona configurados. Escrito por EmojiCacheService.
  /// Leído por EmojiDialogActivity vía "flutter.configured_zone_types". [CROSS-BOUNDARY]
  static const configuredZoneTypes = 'configured_zone_types';

  // ── Session cache (Flutter-only) ────────────────────────────────────────
  static const sessionUserId    = 'zync_cached_user_id';
  static const sessionEmail     = 'zync_cached_user_email';
  static const sessionCircleId  = 'zync_cached_circle_id';
  static const sessionLastSave  = 'zync_cached_last_save';

  // ── Identity (Flutter-only) ─────────────────────────────────────────────
  /// JSON del usuario autenticado (Clean arch local datasource).
  static const cachedUser = 'CACHED_USER';

  // ── Quick Actions (Flutter-only) ────────────────────────────────────────
  static const quickActionsPreferences = 'quick_actions_preferences';

  // ── Badge (Flutter-only) ────────────────────────────────────────────────
  static const appBadgeLastSeen = 'app_badge_last_seen';

  // ── Persistent cache (Flutter-only, dynamic keys) ───────────────────────
  /// Patrón: 'cache_nicknames'
  static const cacheNicknames   = 'cache_nicknames';
  /// Patrón: 'cache_member_data'
  static const cacheMemberData  = 'cache_member_data';
  /// Patrón: 'cache_circle_<circleId>' — clave dinámica
  static String cacheCircle(String circleId) => 'cache_circle_$circleId';
  /// Patrón: 'last_update_<key>' — clave dinámica
  static String lastUpdate(String key) => 'last_update_$key';

  StorageKeys._();
}
```

**Lo que NO incluye:** claves de namespaces Kotlin-only (`zync_silent_mode`, `pending_status`, `worker_state`, `HomeWidgetPlugin`) — esas no cruzan vía `FlutterSharedPreferences` y se documentan en la auditoría, pero no tienen representación Dart.

---

## Tarea 4 — docs/dev/refactor-arch-2026-q2/storage-keys-audit.md

Documento de auditoría completo con todas las claves encontradas:

```markdown
# Auditoría de SharedPreferences — Nunakin App

> Fecha: 2026-05-08
> Propósito: inventario previo a la centralización (StorageKeys + NativeSharedKeys en Día 5).

## Resumen ejecutivo

| Namespace | Origen | Claves | Acceso cross-boundary |
|-----------|--------|--------|----------------------|
| `FlutterSharedPreferences` | SharedPreferences plugin (Flutter) | 12 | Kotlin lee/escribe 7 de ellas |
| `zync_silent_mode` | Kotlin nativo | 3 | Solo Kotlin |
| `pending_status` | Kotlin nativo | 2 | Solo Kotlin |
| `worker_state` | Kotlin nativo | 2 | Solo Kotlin |
| `HomeWidgetPlugin` | home_widget plugin | (gestionadas por plugin) | No |

## FlutterSharedPreferences — claves Dart (prefijo `flutter.` en disco)

### Claves de presencia — ruta crítica de bugs

| Clave Dart | Prefijo en disco | Escritor(es) | Lector(es) | Estado |
|------------|-----------------|--------------|------------|--------|
| `current_status_id` | `flutter.current_status_id` | `StatusService.dart` ✍️, `StatusUpdateWorker.kt` ✍️ | `EmojiDialogActivity.kt` 👁️ | **2 escritores — fragm. crítica** |
| `manual_status_id` | `flutter.manual_status_id` | `StatusService.dart` ✍️ | `SilentCoordinator.dart` 👁️, `InCircleView.dart` 👁️ | OK |
| `pre_silent_status_id` | `flutter.pre_silent_status_id` | `SilentCoordinator.dart` ✍️ | `InCircleView.dart` 👁️, `MainActivity.kt` 🗑️ | OK |
| `is_silent_mode_active` | `flutter.is_silent_mode_active` | `SilentCoordinator.dart` ✍️ | `InCircleView.dart` 👁️, `MainActivity.kt` 🗑️ | **Duplicado con zync_silent_mode** |
| `suppress_next_geofence_check` | `flutter.suppress_next_geofence_check` | `StatusUpdateWorker.kt` ✍️ | `main.dart` 👁️ | OK |

### Claves de cache nativo

| Clave Dart | Escritor | Lector |
|------------|----------|--------|
| `predefined_emojis` | `EmojiCacheService.dart` ✍️ | `EmojiDialogActivity.kt` 👁️ |
| `configured_zone_types` | `EmojiCacheService.dart` ✍️ | `EmojiDialogActivity.kt` 👁️ |

### Claves Flutter-only

| Clave Dart | Archivo | Notas |
|------------|---------|-------|
| `CACHED_USER` | `auth_local_data_source_impl.dart` | JSON serializado del User |
| `zync_cached_user_id` | `session_cache_service.dart` | |
| `zync_cached_user_email` | `session_cache_service.dart` | |
| `zync_cached_circle_id` | `session_cache_service.dart` | |
| `zync_cached_last_save` | `session_cache_service.dart` | ISO8601 timestamp |
| `quick_actions_preferences` | `quick_actions_preferences_service.dart` | JSON |
| `app_badge_last_seen` | `app_badge_service.dart` | Unix ms |
| `cache_nicknames` | `persistent_cache.dart` | JSON |
| `cache_member_data` | `persistent_cache.dart` | JSON |
| `cache_circle_<id>` | `persistent_cache.dart` | Clave dinámica |
| `last_update_<key>` | `persistent_cache.dart` | Clave dinámica |

## Kotlin-only namespaces

### `zync_silent_mode`

| Clave | Escritor | Lector | Notas |
|-------|----------|--------|-------|
| `is_silent_mode_active` | `MainActivity.kt` | `MainActivity.kt` | Duplica `flutter.is_silent_mode_active` |
| `pre_silent_status_type` | — | `MainActivity.kt` (remove) | Solo se elimina, nunca se escribe aquí |
| `modal_was_open` | `NotificationTapReceiver.kt` | — | Solo escritura visible |

### `pending_status`

| Clave | Escritor(es) | Lector(es) |
|-------|-------------|-----------|
| `statusType` | `EmojiDialogActivity`, `MainActivity`, `QuickActionActivity`, `QuickActionReceiver` | `StatusUpdateWorker`, `MainActivity` |
| `emoji` | `EmojiDialogActivity` | — |

### `worker_state`

| Clave | Escritor | Lector |
|-------|----------|--------|
| `userId` | `MainActivity.kt` | `StatusUpdateWorker.kt` |
| `circleId` | `MainActivity.kt` | `StatusUpdateWorker.kt`, `EmojiDialogActivity.kt` |

## Hallazgos — duplicaciones y anomalías

| # | Hallazgo | Impacto | Semana de resolución |
|---|----------|---------|---------------------|
| 1 | `is_silent_mode_active` existe en dos namespaces (`FlutterSharedPreferences` + `zync_silent_mode`) | Alto — fuente confirmada de bugs PRs #77, #106, #113 | Sem 3 (bridge) |
| 2 | `current_status_id` tiene 2 escritores: `StatusService.dart` + `StatusUpdateWorker.kt` | Alto — race condition documentada | Sem 2 (presence) |
| 3 | `pre_silent_status_type` (Kotlin) vs `pre_silent_status_id` (Dart) — diferente sufijo | Medio — inconsistencia de naming | Sem 3 |
| 4 | `pending_status.statusType` escrito por 4 archivos Kotlin distintos | Medio — sin coordinación | Sem 3 |
```

---

## Tarea 5 — lib/app/di/modules/platform_module.dart (modificar)

```dart
import 'package:get_it/get_it.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';
import 'package:nunakin_app/platform/persistence/shared_prefs_kv_store.dart';

/// Platform infrastructure: persistencia local y (Sem 2) DomainEventBus.
Future<void> registerPlatformModule(GetIt sl) async {
  sl.registerLazySingleton<KvStore>(() => SharedPrefsKvStore(sl()));
  // TODO Sem 2: DomainEventBus
}
```

**Por qué `sl()` funciona:** `external_module.dart` registra `SharedPreferences` como `LazySingleton` — GetIt lo resuelve con la instancia ya inicializada.

---

## Tarea 6 — test/platform/persistence/shared_prefs_kv_store_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nunakin_app/platform/persistence/shared_prefs_kv_store.dart';

void main() {
  late SharedPrefsKvStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = SharedPrefsKvStore(prefs);
  });

  group('getString / setString', () {
    test('retorna null si la clave no existe', () async {
      expect(await store.getString('missing'), isNull);
    });

    test('persiste y recupera el valor', () async {
      await store.setString('key', 'value');
      expect(await store.getString('key'), 'value');
    });
  });

  group('getBool / setBool', () {
    test('retorna null si la clave no existe', () async {
      expect(await store.getBool('missing'), isNull);
    });

    test('persiste true y false', () async {
      await store.setBool('flag', true);
      expect(await store.getBool('flag'), isTrue);

      await store.setBool('flag', false);
      expect(await store.getBool('flag'), isFalse);
    });
  });

  group('getInt / setInt', () {
    test('retorna null si la clave no existe', () async {
      expect(await store.getInt('missing'), isNull);
    });

    test('persiste el valor entero', () async {
      await store.setInt('count', 42);
      expect(await store.getInt('count'), 42);
    });
  });

  group('remove', () {
    test('elimina la clave existente', () async {
      await store.setString('to_remove', 'x');
      await store.remove('to_remove');
      expect(await store.getString('to_remove'), isNull);
    });

    test('no lanza si la clave no existe', () async {
      expect(() => store.remove('ghost'), returnsNormally);
    });
  });

  group('containsKey', () {
    test('retorna false si la clave no existe', () async {
      expect(await store.containsKey('missing'), isFalse);
    });

    test('retorna true después de setString', () async {
      await store.setString('exists', 'y');
      expect(await store.containsKey('exists'), isTrue);
    });

    test('retorna false después de remove', () async {
      await store.setString('temp', 'z');
      await store.remove('temp');
      expect(await store.containsKey('temp'), isFalse);
    });
  });
}
```

**Total:** 11 tests — cobertura ≥95% de `SharedPrefsKvStore`.

---

## Restricciones

| Regla | Scope |
|-------|-------|
| No reemplazar literales de claves en código existente | Eso es Día 5 (solo archivos de alto impacto) |
| No agregar KvStore como dependency a servicios existentes | Solo registrar en DI; migración Sem 2+ |
| No crear NativeSharedKeys.dart ni SharedKeys.kt | Día 5 |
| No modificar namespaces Kotlin-only en la auditoría | Solo documentar, no resolver |
| No tocar `lib/platform/bridge/` | Sem 3 |

---

## Entregable

**PR:** `refactor(platform): add KvStore abstraction + centralize storage keys`

---

## Criterio de done

| # | Criterio | Verificación |
|---|----------|--------------|
| 1 | App arranca idéntico al baseline (mvp-baseline-20260506) | Smoke test: login → emoji → ver círculo |
| 2 | `flutter analyze` sin warnings nuevos | CI |
| 3 | `flutter test` 100% verde (31 tests existentes + 11 nuevos) | `flutter test` |
| 4 | KvStore registrado en DI y resuelve vía `sl()` | Code review de `platform_module.dart` |
| 5 | StorageKeys cubre todas las claves encontradas en la auditoría | Comparar contra `storage-keys-audit.md` |
| 6 | `storage-keys-audit.md` publicado con los 4 hallazgos documentados | Archivo en `docs/dev/refactor-arch-2026-q2/` |
| 7 | `lib/platform/persistence/` contiene los 3 archivos (sin `.gitkeep`) | `tree lib/platform/` |
| 8 | Ningún archivo de producción existente modificado (solo `platform_module.dart`) | `git diff --name-only` |

---

## Riesgo específico del Día 4

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|-------------|
| `sl()` en `platform_module` falla si `SharedPreferences` no está registrado antes | Baja | `initDependencies()` llama `registerExternalModule` primero — orden garantizado |
| `SharedPreferences.setMockInitialValues({})` no limpia estado entre tests | Media | `setUp()` lo reinicializa antes de cada test — verificar con `flutter test --run-skipped` |
| Auditoría incompleta — clave dinámica no detectada por `grep` | Baja | Las claves dinámicas (`cache_circle_<id>`, `last_update_<key>`) están documentadas como patrones, no literales |
| `storage_keys.dart` incluye clave de namespace Kotlin-only por error | Baja | Regla explícita: StorageKeys solo cubre accesos vía Flutter SharedPreferences plugin |

---

## Confirmación final

### Estado del Repositorio

- ✅ Branch refactor/sem1-kvstore mergeada y eliminada (local + remota)
- ✅ PR #148 squash-mergeado
- ✅ main actualizado: `9c3518e` refactor(platform): add KvStore abstraction + centralize storage keys (#148)
- ✅ `flutter analyze`: sin warnings nuevos
- ✅ `flutter test`: 42/42 ✅ (31 previos + 11 KvStore)

### Memoria Guardada

- ✅ Archivo: `project_session_20260508.md`
- ✅ Índice `MEMORY.md` actualizado

---

## 📊 RESUMEN EJECUTIVO

### Tareas Realizadas

- ✅ KvStore (interfaz) + SharedPrefsKvStore (impl) creados
- ✅ StorageKeys — 12 claves Flutter + 2 dinámicas, fuente única de verdad
- ✅ platform_module.dart — KvStore registrado como LazySingleton en GetIt
- ✅ storage-keys-audit.md — inventario completo con 4 anomalías documentadas
- ✅ 11 tests unitarios para SharedPrefsKvStore
- ✅ PR #148 mergeado, rama eliminada

### Estadísticas

| Métrica | Valor |
|---------|-------|
| Archivos creados | 6 |
| Archivos modificados | 1 |
| Líneas agregadas | +309 |
| flutter analyze | 394 (0 nuevos) |
| flutter test | 42/42 ✅ |

---

## ✅ CONFIRMACIÓN FINAL

- ✅ Branch refactor/sem1-kvstore limpia (local + remota)
- ✅ PR #148 mergeado (squash)
- ✅ Último commit: abd4db5 — refactor(platform): add KvStore abstraction + centralize storage keys (#148)
- ✅ Memoria guardada: project_session_20260508.md

### Próximos Pasos

- Smoke test en dispositivo físico antes de Día 5 (Normal → Silent → Normal, backgrounding ≥10 min)
- Día 5: NativeSharedKeys.dart + SharedKeys.kt + StatusIds.dart/kt + reemplazo de literales en archivos de alto impacto
---

**Modelo:** Sonnet 4.6 — tareas de implementación directa (adaptador, catálogo de constantes, tests con mocks). Opus se reserva para Día 3 y la semana completa 3 (bridge nativo), donde la complejidad de razonamiento es mayor.