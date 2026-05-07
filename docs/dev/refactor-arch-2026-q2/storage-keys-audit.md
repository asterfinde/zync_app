# Auditoría de SharedPreferences — Nunakin App

> Fecha: 2026-05-08
> Propósito: inventario previo a la centralización (StorageKeys Día 4 + NativeSharedKeys/SharedKeys.kt en Día 5).

---

## Resumen ejecutivo

| Namespace | Origen | Claves | Acceso cross-boundary |
|-----------|--------|--------|-----------------------|
| `FlutterSharedPreferences` | SharedPreferences plugin (Flutter) | 12 | Kotlin lee/escribe 7 de ellas |
| `zync_silent_mode` | Kotlin nativo | 3 | Solo Kotlin |
| `pending_status` | Kotlin nativo | 2 | Solo Kotlin |
| `worker_state` | Kotlin nativo | 2 | Solo Kotlin |
| `HomeWidgetPlugin` | home_widget plugin | (gestionadas por plugin) | No |

---

## FlutterSharedPreferences — claves Dart

> Las claves escritas desde Flutter se almacenan en disco con prefijo `flutter.`
> (comportamiento del plugin). En código Dart se usan **sin** el prefijo.

### Claves de presencia — ruta crítica de bugs

| Clave Dart | Clave en disco | Escritor(es) | Lector(es) | Anomalía |
|------------|---------------|--------------|------------|---------|
| `current_status_id` | `flutter.current_status_id` | `status_service.dart` ✍️, `StatusUpdateWorker.kt` ✍️ | `EmojiDialogActivity.kt` 👁️ | **2 escritores — fragmentación crítica** |
| `manual_status_id` | `flutter.manual_status_id` | `status_service.dart` ✍️ | `silent_functionality_coordinator.dart` 👁️, `in_circle_view.dart` 👁️ | — |
| `pre_silent_status_id` | `flutter.pre_silent_status_id` | `silent_functionality_coordinator.dart` ✍️ | `in_circle_view.dart` 👁️, `MainActivity.kt` 🗑️ | — |
| `is_silent_mode_active` | `flutter.is_silent_mode_active` | `silent_functionality_coordinator.dart` ✍️ | `in_circle_view.dart` 👁️, `MainActivity.kt` 🗑️ | **Duplicado con `zync_silent_mode`** |
| `suppress_next_geofence_check` | `flutter.suppress_next_geofence_check` | `StatusUpdateWorker.kt` ✍️ | `main.dart` 👁️ | — |

### Claves de cache nativo (Flutter → Kotlin)

| Clave Dart | Clave en disco | Escritor | Lector |
|------------|---------------|----------|--------|
| `predefined_emojis` | `flutter.predefined_emojis` | `emoji_cache_service.dart` ✍️ | `EmojiDialogActivity.kt` 👁️ |
| `configured_zone_types` | `flutter.configured_zone_types` | `emoji_cache_service.dart` ✍️ | `EmojiDialogActivity.kt` 👁️ |

### Claves Flutter-only

| Clave Dart | Archivo | Tipo | Notas |
|------------|---------|------|-------|
| `CACHED_USER` | `auth_local_data_source_impl.dart` | String (JSON) | User serializado |
| `zync_cached_user_id` | `session_cache_service.dart` | String | UID Firebase |
| `zync_cached_user_email` | `session_cache_service.dart` | String | Email del usuario |
| `zync_cached_circle_id` | `session_cache_service.dart` | String | ID del círculo activo |
| `zync_cached_last_save` | `session_cache_service.dart` | String | ISO 8601 timestamp |
| `quick_actions_preferences` | `quick_actions_preferences_service.dart` | String (JSON) | IDs de quick actions configuradas |
| `app_badge_last_seen` | `app_badge_service.dart` | Int | Unix ms del último badge visto |
| `cache_nicknames` | `persistent_cache.dart` | String (JSON) | Nicknames de miembros |
| `cache_member_data` | `persistent_cache.dart` | String (JSON) | Datos de miembros |
| `cache_circle_<circleId>` | `persistent_cache.dart` | String (JSON) | Clave dinámica por círculo |
| `last_update_<key>` | `persistent_cache.dart` | String (ISO 8601) | Timestamp de cache por clave dinámica |

---

## Kotlin-only namespaces

> Estas claves no se acceden desde Dart. No tienen representación en `StorageKeys`.

### `zync_silent_mode`

| Clave | Escritor | Lector | Notas |
|-------|----------|--------|-------|
| `is_silent_mode_active` | `MainActivity.kt` ✍️ | `MainActivity.kt` 👁️ | Duplica `flutter.is_silent_mode_active` — Anomalía #1 |
| `pre_silent_status_type` | — | `MainActivity.kt` 🗑️ (solo remove) | Nunca se escribe, solo se elimina |
| `modal_was_open` | `NotificationTapReceiver.kt` ✍️ | — | Solo escritura visible |

### `pending_status`

| Clave | Escritor(es) | Lector(es) |
|-------|-------------|-----------|
| `statusType` | `EmojiDialogActivity.kt`, `MainActivity.kt`, `QuickActionActivity.kt`, `QuickActionReceiver.kt` | `StatusUpdateWorker.kt`, `MainActivity.kt` |
| `emoji` | `EmojiDialogActivity.kt` ✍️ | — |

### `worker_state`

| Clave | Escritor | Lector |
|-------|----------|--------|
| `userId` | `MainActivity.kt` ✍️ | `StatusUpdateWorker.kt` 👁️ |
| `circleId` | `MainActivity.kt` ✍️ | `StatusUpdateWorker.kt` 👁️, `EmojiDialogActivity.kt` 👁️ |

### `HomeWidgetPlugin`

| Clave | Escritor | Lector | Notas |
|-------|----------|--------|-------|
| (plugin-managed) | `ZyncStatusWidgetProvider.kt` | plugin | No requiere constantes propias |

---

## Hallazgos — duplicaciones y anomalías

| # | Hallazgo | Impacto | Semana de resolución |
|---|----------|---------|---------------------|
| 1 | `is_silent_mode_active` existe en dos namespaces: `FlutterSharedPreferences` (escrito por Dart) y `zync_silent_mode` (escrito por Kotlin nativo) | **Alto** — fuente confirmada de bugs PRs #77, #106, #113 | Sem 3 (Native Bridge) |
| 2 | `current_status_id` tiene 2 escritores independientes: `StatusService.dart` + `StatusUpdateWorker.kt` sin coordinación | **Alto** — race condition documentada, raíz de AUTH-20260505-002 | Sem 2 (Presence state machine) |
| 3 | `pre_silent_status_type` (Kotlin `zync_silent_mode`) vs `pre_silent_status_id` (Dart `FlutterSharedPreferences`) — sufijos distintos para el mismo concepto | **Medio** — inconsistencia de naming cross-boundary | Sem 3 |
| 4 | `pending_status.statusType` escrito por 4 archivos Kotlin distintos sin dueño único | **Medio** — sin coordinación, riesgo de escrituras concurrentes | Sem 3 |

---

## Cobertura en StorageKeys

Las 12 claves del namespace `FlutterSharedPreferences` están cubiertas en
`lib/platform/persistence/storage_keys.dart`. Los namespaces Kotlin-only
(`zync_silent_mode`, `pending_status`, `worker_state`) se documentan aquí
pero no tienen representación Dart — se centralizan en Sem 3 junto con el
Native Bridge unificado.
