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
