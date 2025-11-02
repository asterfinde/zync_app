/// Monitor de performance para testing
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, int> _durations = {};
  
  /// Iniciar medición
  static void start(String label) {
    _startTimes[label] = DateTime.now();
    print('⏱️ [$label] START at ${DateTime.now()}');
  }
  
  /// Terminar medición y retornar duración en ms
  static int stop(String label) {
    final start = _startTimes[label];
    if (start == null) {
      print('⚠️ [$label] No start time found!');
      return -1;
    }
    
    final duration = DateTime.now().difference(start).inMilliseconds;
    _durations[label] = duration;
    
    final emoji = duration < 100 ? '✅' : duration < 500 ? '⚡' : '⏰';
    print('$emoji [$label] STOP - Duration: ${duration}ms');
    
    return duration;
  }
  
  /// Obtener todas las métricas
  static Map<String, int> getMetrics() => Map.from(_durations);
  
  /// Limpiar métricas
  static void clear() {
    _startTimes.clear();
    _durations.clear();
    print('🗑️ [PerformanceMonitor] Cleared all metrics');
  }
  
  /// Imprimir resumen
  static void printSummary() {
    print('\n📊 ===== PERFORMANCE SUMMARY =====');
    _durations.forEach((label, duration) {
      final emoji = duration < 100 ? '✅' : duration < 500 ? '⚡' : '⏰';
      print('$emoji $label: ${duration}ms');
    });
    print('================================\n');
  }
}
