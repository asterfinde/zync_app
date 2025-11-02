import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Cache de prueba ultra-simple
class TestCache {
  static SharedPreferences? _prefs;
  static bool _isInitialized = false;
  
  /// Inicializar cache
  static Future<void> init() async {
    if (_isInitialized) {
      print('⚡ [TestCache] Ya inicializado');
      return;
    }
    
    print('🚀 [TestCache] Inicializando...');
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    print('✅ [TestCache] Inicializado');
  }
  
  /// Guardar lista de strings
  static Future<void> saveList(List<String> items) async {
    if (!_isInitialized) {
      print('⚠️ [TestCache] No inicializado');
      return;
    }
    
    await _prefs?.setString('test_items', jsonEncode(items));
    print('💾 [TestCache] Guardados ${items.length} items');
  }
  
  /// Cargar lista de strings
  static List<String> loadList() {
    if (!_isInitialized) {
      print('⚠️ [TestCache] No inicializado');
      return [];
    }
    
    final json = _prefs?.getString('test_items');
    if (json == null || json.isEmpty) {
      print('❌ [TestCache] No hay datos');
      return [];
    }
    
    final list = List<String>.from(jsonDecode(json));
    print('✅ [TestCache] Cargados ${list.length} items');
    return list;
  }
  
  /// Limpiar cache
  static Future<void> clear() async {
    await _prefs?.clear();
    print('🗑️ [TestCache] Cache limpiado');
  }
}
