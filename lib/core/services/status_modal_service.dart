import 'dart:developer';

import 'package:flutter/services.dart';

/// Servicio para manejar la nueva StatusModalActivity transparente (Point 15)
/// Permite abrir modales sin mostrar la app completa
class StatusModalService {
  static const MethodChannel _channel = MethodChannel('com.datainfers.zync/status_modal');
  
  static bool _isInitialized = false;

  /// Inicializa el servicio del modal transparente
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Configurar handler para cuando Android abre el modal
      _channel.setMethodCallHandler(_handleMethodCall);
      
      _isInitialized = true;
      log('[StatusModalService] ✅ Servicio inicializado');
      
    } catch (e) {
      log('[StatusModalService] ❌ Error inicializando: $e');
    }
  }

  /// Maneja llamadas desde Android
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    log('[StatusModalService] Recibida llamada: ${call.method}');
    
    switch (call.method) {
      case 'openStatusModal':
        await _openStatusModal();
        return true;
      case 'closeModal':
        await _closeModal();
        return true;
      default:
        log('[StatusModalService] Método no reconocido: ${call.method}');
        throw PlatformException(
          code: 'METHOD_NOT_FOUND',
          message: 'Method ${call.method} not found',
        );
    }
  }

  /// Abre el modal de estados (llamado desde Android)
  static Future<void> _openStatusModal() async {
    try {
      log('[StatusModalService] 🚀 Abriendo modal desde notificación');
      
      // TODO: Aquí abrir el StatusSelectorOverlay
      // Por ahora solo logueamos
      log('[StatusModalService] ✅ Modal abierto silenciosamente');
      
    } catch (e) {
      log('[StatusModalService] ❌ Error abriendo modal: $e');
    }
  }

  /// Cierra el modal (llamado desde Flutter)
  static Future<void> _closeModal() async {
    try {
      log('[StatusModalService] 🔒 Cerrando modal');
      
      // Notificar a Android que cierre la activity
      await _channel.invokeMethod('closeModal');
      
      log('[StatusModalService] ✅ Modal cerrado');
      
    } catch (e) {
      log('[StatusModalService] ❌ Error cerrando modal: $e');
    }
  }

  /// Método público para cerrar desde Flutter
  static Future<void> closeModal() async {
    await _closeModal();
  }
}