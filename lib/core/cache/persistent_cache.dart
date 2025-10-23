import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache persistente en disco usando SharedPreferences
/// Se mantiene incluso después de cerrar la app (Cold Start)
class PersistentCache {
  static SharedPreferences? _prefs;
  static bool _isInitialized = false;
  
  /// Inicializa el cache persistente
  /// DEBE llamarse en main() antes de runApp()
  static Future<void> init() async {
    if (_isInitialized) {
      print('⚡ [PersistentCache] Ya está inicializado, saltando...');
      return;
    }
    
    try {
      print('🚀 [PersistentCache] Inicializando...');
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      print('✅ [PersistentCache] Inicializado exitosamente');
    } catch (e) {
      print('❌ [PersistentCache] Error al inicializar: $e');
      rethrow;
    }
  }
  
  /// Verifica si está inicializado
  static bool get isInitialized => _isInitialized;
  
  // ========================================================================
  // NICKNAMES
  // ========================================================================
  
  /// Guarda nicknames en disco
  static Future<void> saveNicknames(Map<String, String> nicknames) async {
    if (!_isInitialized) {
      print('⚠️ [PersistentCache] No inicializado, no se puede guardar nicknames');
      return;
    }
    
    try {
      await _prefs?.setString('cache_nicknames', jsonEncode(nicknames));
      print('💾 [PersistentCache] Nicknames guardados (${nicknames.length} items)');
    } catch (e) {
      print('❌ [PersistentCache] Error guardando nicknames: $e');
    }
  }
  
  /// Carga nicknames desde disco
  static Map<String, String> loadNicknames() {
    if (!_isInitialized) {
      print('⚠️ [PersistentCache] No inicializado, retornando mapa vacío');
      return {};
    }
    
    try {
      final json = _prefs?.getString('cache_nicknames');
      if (json == null || json.isEmpty) {
        print('❌ [PersistentCache] No hay nicknames cacheados');
        return {};
      }
      
      final decoded = Map<String, String>.from(jsonDecode(json));
      print('✅ [PersistentCache] Nicknames cargados (${decoded.length} items)');
      return decoded;
    } catch (e) {
      print('❌ [PersistentCache] Error cargando nicknames: $e');
      return {};
    }
  }
  
  // ========================================================================
  // MEMBER DATA (Estados de miembros)
  // ========================================================================
  
  /// Guarda datos de miembros en disco
  static Future<void> saveMemberData(Map<String, Map<String, dynamic>> data) async {
    if (!_isInitialized) {
      print('⚠️ [PersistentCache] No inicializado, no se puede guardar member data');
      return;
    }
    
    try {
      await _prefs?.setString('cache_member_data', jsonEncode(data));
      print('💾 [PersistentCache] Member data guardado (${data.length} items)');
    } catch (e) {
      print('❌ [PersistentCache] Error guardando member data: $e');
    }
  }
  
  /// Carga datos de miembros desde disco
  static Map<String, Map<String, dynamic>> loadMemberData() {
    if (!_isInitialized) {
      print('⚠️ [PersistentCache] No inicializado, retornando mapa vacío');
      return {};
    }
    
    try {
      final json = _prefs?.getString('cache_member_data');
      if (json == null || json.isEmpty) {
        print('❌ [PersistentCache] No hay member data cacheado');
        return {};
      }
      
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final result = decoded.map((key, value) => 
        MapEntry(key, Map<String, dynamic>.from(value as Map))
      );
      print('✅ [PersistentCache] Member data cargado (${result.length} items)');
      return result;
    } catch (e) {
      print('❌ [PersistentCache] Error cargando member data: $e');
      return {};
    }
  }
  
  // ========================================================================
  // CIRCLE INFO
  // ========================================================================
  
  /// Guarda información del círculo
  static Future<void> saveCircleInfo(String circleId, Map<String, dynamic> info) async {
    if (!_isInitialized) {
      print('⚠️ [PersistentCache] No inicializado, no se puede guardar circle info');
      return;
    }
    
    try {
      await _prefs?.setString('cache_circle_$circleId', jsonEncode(info));
      print('💾 [PersistentCache] Circle info guardado para: $circleId');
    } catch (e) {
      print('❌ [PersistentCache] Error guardando circle info: $e');
    }
  }
  
  /// Carga información del círculo
  static Map<String, dynamic>? loadCircleInfo(String circleId) {
    if (!_isInitialized) {
      print('⚠️ [PersistentCache] No inicializado, retornando null');
      return null;
    }
    
    try {
      final json = _prefs?.getString('cache_circle_$circleId');
      if (json == null || json.isEmpty) {
        print('❌ [PersistentCache] No hay circle info para: $circleId');
        return null;
      }
      
      final decoded = Map<String, dynamic>.from(jsonDecode(json));
      print('✅ [PersistentCache] Circle info cargado para: $circleId');
      return decoded;
    } catch (e) {
      print('❌ [PersistentCache] Error cargando circle info: $e');
      return null;
    }
  }
  
  // ========================================================================
  // UTILIDADES
  // ========================================================================
  
  /// Limpia TODO el cache persistente
  static Future<void> clearAll() async {
    if (!_isInitialized) {
      print('⚠️ [PersistentCache] No inicializado');
      return;
    }
    
    try {
      await _prefs?.clear();
      print('🗑️ [PersistentCache] Todo el cache limpiado');
    } catch (e) {
      print('❌ [PersistentCache] Error limpiando cache: $e');
    }
  }
  
  /// Obtiene todas las keys del cache
  static Set<String> getAllKeys() {
    if (!_isInitialized) return {};
    return _prefs?.getKeys() ?? {};
  }
  
  /// Guarda timestamp de última actualización
  static Future<void> saveLastUpdate(String key) async {
    if (!_isInitialized) return;
    await _prefs?.setString('last_update_$key', DateTime.now().toIso8601String());
  }
  
  /// Obtiene timestamp de última actualización
  static DateTime? getLastUpdate(String key) {
    if (!_isInitialized) return null;
    final timestamp = _prefs?.getString('last_update_$key');
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }
}
