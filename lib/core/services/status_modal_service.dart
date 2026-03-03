import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/notification_status_selector.dart'; // NUEVO: Modal específico para notificaciones
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart'; // Para acceder al navigatorKey global

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

  /// Contexto global para el modal (se establece cuando se abre la activity)
  // TODO: Usar cuando se implemente navegación desde notificación
  // static BuildContext? _modalContext;

  /// Establece el contexto para el modal
  static void setModalContext(BuildContext context) {
    // _modalContext = context;
    log('[StatusModalService] 📍 Contexto establecido');
  }

  /// Point 21 FASE 5: Abre el modal de estados (llamado desde Android)
  /// Llamado automáticamente cuando StatusModalActivity se abre
  static Future<void> _openStatusModal() async {
    try {
      log('[StatusModalService] 🚀 [FASE 5] Abriendo modal desde notificación');

      // Verificar autenticación
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        log('[StatusModalService] ❌ Usuario no autenticado - cerrando activity');
        await _closeModal();
        return;
      }

      // Esperar para asegurar que Flutter esté completamente listo
      await Future.delayed(const Duration(milliseconds: 150));

      // FASE 5: Obtener contexto del navigatorKey global
      // StatusModalActivity comparte el mismo engine que MainActivity
      final context = navigatorKey.currentContext;

      if (context == null || !context.mounted) {
        log('[StatusModalService] ❌ NavigatorKey context no disponible');

        // Reintentar una vez más
        await Future.delayed(const Duration(milliseconds: 200));

        final retryContext = navigatorKey.currentContext;
        if (retryContext == null || !retryContext.mounted) {
          log('[StatusModalService] ❌ Context aún no disponible - cerrando activity');
          await _closeModal();
          return;
        }
      }

      final finalContext = navigatorKey.currentContext!;
      log('[StatusModalService] ✅ Context disponible - mostrando overlay');

      // Abrir el NotificationStatusSelector (específico para notificaciones)
      Navigator.of(finalContext).push(
        PageRouteBuilder(
          opaque: false, // Transparente
          barrierDismissible: true,
          pageBuilder: (context, animation, secondaryAnimation) {
            return NotificationStatusSelector(
              onClose: () async {
                log('[StatusModalService] Modal cerrado por usuario');
                // Cerrar la activity nativa
                await closeModal();
              },
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Animación de fade in
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );

      log('[StatusModalService] ✅ Modal abierto exitosamente');
    } catch (e, stackTrace) {
      log('[StatusModalService] ❌ Error abriendo modal: $e');
      log('[StatusModalService] Stack: $stackTrace');
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

  /// Point 21 FASE 5: Abre StatusModalActivity desde Flutter
  /// Permite abrir el modal SIN abrir la app completa
  static Future<void> openModal() async {
    try {
      log('[StatusModalService] 🚀 Solicitando apertura de StatusModalActivity...');

      // Verificar que el usuario esté autenticado antes de abrir
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        log('[StatusModalService] ❌ Usuario no autenticado - no se puede abrir modal');
        return;
      }

      // Llamar a Android para abrir StatusModalActivity
      await _channel.invokeMethod('openModal');

      log('[StatusModalService] ✅ StatusModalActivity solicitada');
    } catch (e) {
      log('[StatusModalService] ❌ Error solicitando modal: $e');
      rethrow;
    }
  }
}
