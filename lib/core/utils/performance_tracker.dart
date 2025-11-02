// lib/core/utils/performance_tracker.dart
// Sistema de medición de rendimiento para Point 20

import 'package:flutter/foundation.dart';

/// Tracker de rendimiento para identificar cuellos de botella en min/max
class PerformanceTracker {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, Duration> _measurements = {};
  static DateTime? _appPausedAt;
  static DateTime? _appResumedAt;

  /// Iniciar medición de una operación
  static void start(String operation) {
    _startTimes[operation] = DateTime.now();
    if (kDebugMode) {
      debugPrint('⏱️ [START] $operation');
    }
  }

  /// Finalizar medición de una operación
  static void end(String operation) {
    if (_startTimes.containsKey(operation)) {
      final duration = DateTime.now().difference(_startTimes[operation]!);
      _measurements[operation] = duration;
      
      // Alertar si toma más de 300ms
      final color = duration.inMilliseconds > 300 ? '🔴' : '✅';
      if (kDebugMode) {
        debugPrint('$color [END] $operation - ${duration.inMilliseconds}ms');
      }
      
      _startTimes.remove(operation);
    }
  }

  /// Registrar cuando app se minimiza
  static void onAppPaused() {
    _appPausedAt = DateTime.now();
    if (kDebugMode) {
      debugPrint('⏸️ [APP] Minimizada a las ${_appPausedAt?.toIso8601String()}');
    }
  }

  /// Registrar cuando app se maximiza
  static void onAppResumed() {
    _appResumedAt = DateTime.now();
    if (_appPausedAt != null) {
      final pausedDuration = _appResumedAt!.difference(_appPausedAt!);
      if (kDebugMode) {
        debugPrint('▶️ [APP] Restaurada después de ${pausedDuration.inSeconds}s');
      }
    }
  }

  /// Obtener reporte completo
  static String getReport() {
    final buffer = StringBuffer();
    buffer.writeln('\n📊 === REPORTE DE RENDIMIENTO ===\n');
    
    // Ordenar por duración (más lento primero)
    final sorted = _measurements.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final entry in sorted) {
      final ms = entry.value.inMilliseconds;
      final icon = ms > 500 ? '🔴' : (ms > 200 ? '🟡' : '🟢');
      buffer.writeln('$icon ${entry.key}: ${ms}ms');
    }
    
    buffer.writeln('\n=================================\n');
    return buffer.toString();
  }

  /// Limpiar mediciones
  static void clear() {
    _measurements.clear();
    _startTimes.clear();
  }

  /// Obtener todas las mediciones para análisis
  static Map<String, Duration> get measurements => Map.from(_measurements);
}
