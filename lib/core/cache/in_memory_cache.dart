/// Cache simple en memoria para datos de la app
/// Se pierde cuando la app se cierra, pero es MUY rápido para Warm Resume
class InMemoryCache {
  static final Map<String, dynamic> _cache = {};
  
  /// Guarda un valor en el cache
  static void set(String key, dynamic value) {
    _cache[key] = value;
    print('💾 [InMemoryCache] Guardado: $key');
  }
  
  /// Obtiene un valor del cache
  static T? get<T>(String key) {
    final value = _cache[key];
    if (value != null) {
      print('✅ [InMemoryCache] Hit: $key');
    } else {
      print('❌ [InMemoryCache] Miss: $key');
    }
    return value as T?;
  }
  
  /// Verifica si existe una key en el cache
  static bool has(String key) {
    return _cache.containsKey(key);
  }
  
  /// Limpia todo el cache
  static void clear() {
    _cache.clear();
    print('🗑️ [InMemoryCache] Cache limpiado');
  }
  
  /// Elimina una key específica
  static void remove(String key) {
    _cache.remove(key);
    print('🗑️ [InMemoryCache] Eliminado: $key');
  }
  
  /// Obtiene el tamaño del cache
  static int get size => _cache.length;
  
  /// Obtiene todas las keys
  static List<String> get keys => _cache.keys.toList();
}
