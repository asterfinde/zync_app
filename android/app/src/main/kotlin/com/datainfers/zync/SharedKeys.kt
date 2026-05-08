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
