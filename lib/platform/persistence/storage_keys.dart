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
  static const sessionUserId   = 'zync_cached_user_id';
  static const sessionEmail    = 'zync_cached_user_email';
  static const sessionCircleId = 'zync_cached_circle_id';
  static const sessionLastSave = 'zync_cached_last_save';

  // ── Identity (Flutter-only) ─────────────────────────────────────────────
  /// JSON del usuario autenticado (Clean arch local datasource).
  static const cachedUser = 'CACHED_USER';

  // ── Quick Actions (Flutter-only) ────────────────────────────────────────
  static const quickActionsPreferences = 'quick_actions_preferences';

  // ── Badge (Flutter-only) ────────────────────────────────────────────────
  static const appBadgeLastSeen = 'app_badge_last_seen';

  // ── Persistent cache (Flutter-only, dynamic keys) ───────────────────────
  static const cacheNicknames  = 'cache_nicknames';
  static const cacheMemberData = 'cache_member_data';
  /// Clave dinámica — patrón: `cache_circle_<circleId>`
  static String cacheCircle(String circleId) => 'cache_circle_$circleId';
  /// Clave dinámica — patrón: `last_update_<key>`
  static String lastUpdate(String key) => 'last_update_$key';

  StorageKeys._();
}
