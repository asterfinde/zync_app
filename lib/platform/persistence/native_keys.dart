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

  /// Último estado seleccionado manualmente. Escrito por: StatusService (Dart)
  /// y StatusUpdateWorker.kt (pick desde BN — fix 2026-08-02). Se escribe
  /// incluso mientras MS está activo: MainActivity.onCreate() autodesactiva MS
  /// al reabrir la app (Regla 1) sin sincronizar esta clave desde
  /// pre_silent_status_id (a diferencia de ExitSilentMode, que sí lo hace) —
  /// si quedara vieja, una reactivación posterior de MS sembraría
  /// pre_silent_status_id con un valor incorrecto.
  /// Leído por: SilentCoordinator, InCircleView.
  static const manualStatusId = 'manual_status_id';

  /// Snapshot del estado activo mientras Silent Mode está encendido — no es
  /// solo el estado previo a activar MS: se re-escribe ante cada selección
  /// deliberada mientras MS sigue activo (fix 2026-08-02, borde verde
  /// congelado en la BN). Escrito por: SilentCoordinator (al activar),
  /// StatusService (Dart, selección con MS activo) y StatusUpdateWorker.kt
  /// (pick desde BN, siempre con MS activo). Leído por: InCircleView,
  /// EmojiDialogActivity.kt. Eliminado por: MainActivity al desactivar Silent
  /// Mode — dos vías: ExitSilentMode (logout, sincroniza manualStatusId) y
  /// MainActivity.onCreate() Regla 1 (reapertura de app, NO lo sincroniza).
  static const preSilentStatusId = 'pre_silent_status_id';

  /// Flag de Silent Mode activo (namespace Flutter).
  /// Escrito por: SilentCoordinator. Leído/eliminado por: MainActivity.
  /// NOTA: coexiste con zync_silent_mode.is_silent_mode_active en Kotlin — Sem 3.
  static const isSilentModeActive = 'is_silent_mode_active';

  /// Timestamp (ms epoch) de cuándo se activó Silent Mode.
  /// Escrito por: EnterSilentMode use case.
  /// Leído por: SharedPrefsPresenceRepository.
  /// Eliminado por: ExitSilentMode use case (y MainActivity al desactivar Silent Mode).
  static const silentEnteredAt = 'silent_entered_at';

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
