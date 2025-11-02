// lib/core/services/keep_alive_service.dart

import 'package:flutter/services.dart';
import 'dart:developer';

/// Servicio para mantener el proceso vivo (patrón WhatsApp/Telegram)
/// 
/// Inicia un servicio foreground en Android que evita que el sistema mate el proceso
/// cuando la app está en background. Esto hace que la app se sienta instantánea.
class KeepAliveService {
  static const _channel = MethodChannel('zync/keep_alive');
  static bool _isRunning = false;

  /// Iniciar el servicio keep-alive
  /// 
  /// Debe llamarse cuando la app se minimiza
  static Future<void> start() async {
    if (_isRunning) {
      log('[KeepAlive] ⚠️ Servicio ya está corriendo, skip');
      return;
    }

    try {
      log('[KeepAlive] 🟢 Iniciando servicio...');
      await _channel.invokeMethod('start');
      _isRunning = true;
      log('[KeepAlive] ✅ Servicio iniciado');
    } catch (e) {
      log('[KeepAlive] ❌ Error iniciando servicio: $e');
    }
  }

  /// Detener el servicio keep-alive
  /// 
  /// Debe llamarse cuando la app se maximiza o cierra
  static Future<void> stop() async {
    if (!_isRunning) {
      log('[KeepAlive] ⚠️ Servicio no está corriendo, skip');
      return;
    }

    try {
      log('[KeepAlive] 🔴 Deteniendo servicio...');
      await _channel.invokeMethod('stop');
      _isRunning = false;
      log('[KeepAlive] ✅ Servicio detenido');
    } catch (e) {
      log('[KeepAlive] ❌ Error deteniendo servicio: $e');
    }
  }

  /// Verificar si el servicio está corriendo
  static bool get isRunning => _isRunning;
}
