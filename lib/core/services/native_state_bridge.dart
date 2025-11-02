// Servicio para sincronizar estado Flutter ↔ Kotlin nativo
// 
// FASE 1: Bridge entre Flutter y NativeStateManager.kt
// 
// Responsabilidades:
// - Notificar a Kotlin cuando cambia userId (login/logout)
// - Leer estado desde Kotlin en cold start (más rápido que Flutter)

import 'package:flutter/services.dart';
import 'dart:developer';

/// Puente de comunicación con el estado nativo de Kotlin
/// 
/// Sincroniza userId, email, circleId entre Flutter y Android nativo
/// usando SQLite Room (mucho más rápido que SharedPreferences)
class NativeStateBridge {
  static const _channel = MethodChannel('zync/native_state');

  /// Notificar a Kotlin que el usuario cambió (login, logout, etc)
  /// 
  /// Kotlin guarda en SQLite Room (~5-10ms async)
  /// Disponible instantáneamente en próximo cold start
  static Future<void> setUserId({
    required String userId,
    String email = '',
    String circleId = '',
  }) async {
    try {
      final start = DateTime.now();
      log('[NativeState] 📤 Enviando a Kotlin: $userId');
      
      await _channel.invokeMethod('setUserId', {
        'userId': userId,
        'email': email,
        'circleId': circleId,
      });
      
      final duration = DateTime.now().difference(start);
      log('[NativeState] ✅ Kotlin actualizado en ${duration.inMilliseconds}ms');
    } catch (e) {
      log('[NativeState] ❌ Error sincronizando: $e');
    }
  }

  /// Obtener userId desde Kotlin (útil en cold start)
  /// 
  /// Lee desde cache en memoria de Kotlin (<1ms)
  /// Si Kotlin tiene estado guardado, Flutter puede saltear init
  static Future<String?> getUserId() async {
    try {
      final start = DateTime.now();
      final userId = await _channel.invokeMethod<String>('getUserId');
      final duration = DateTime.now().difference(start);
      
      log('[NativeState] 📥 Recibido de Kotlin en ${duration.inMilliseconds}ms: $userId');
      return userId;
    } catch (e) {
      log('[NativeState] ❌ Error obteniendo userId: $e');
      return null;
    }
  }
  
  /// Debug: Obtener info completa del estado nativo
  static Future<String?> getDebugInfo() async {
    try {
      final info = await _channel.invokeMethod<String>('getDebugInfo');
      log('[NativeState] 🔍 Debug info:\n$info');
      return info;
    } catch (e) {
      log('[NativeState] ❌ Error obteniendo debug info: $e');
      return null;
    }
  }
}
