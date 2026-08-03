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

  /// Recarga el store desde disco. Necesario cuando el proceso Kotlin
  /// escribió directo al archivo nativo sin pasar por este store — ver
  /// DT-PREFS-STALE-CACHE.
  Future<void> reload();
}
