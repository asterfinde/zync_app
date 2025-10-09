import 'package:flutter/material.dart';
import '../../notifications/notification_service.dart';
import '../../quick_actions/quick_actions_service.dart';
import '../../widgets/status_selector_overlay.dart';
import '../../features/circle/domain_old/entities/user_status.dart';

/// Coordinador de funcionalidad silenciosa - Integra sin romper lo existente
class SilentFunctionalityCoordinator {
  static bool _isInitialized = false;
  static BuildContext? _context;

  /// Inicializa toda la funcionalidad silenciosa - SOLO SERVICIOS BASE
  static Future<void> initialize(BuildContext context) async {
    print('');
    print('=== SILENT COORDINATOR INITIALIZE CALLED ===');
    print('[SilentCoordinator] 🚀 INICIO del método initialize() - _isInitialized: $_isInitialized');
    if (_isInitialized) {
      print('[SilentCoordinator] ⚠️ Ya está inicializado, saliendo...');
      return;
    }
    
    _context = context;
    
    try {
      // 1. Inicializar servicios existentes (sin romper nada)
      print('[SilentCoordinator] 🔧 Inicializando servicios base...');
      
      await NotificationService.initialize();
      await QuickActionsService.initialize();
      
      // 2. Configurar el handler para la notificación persistente
      NotificationService.setQuickActionTapHandler(_handleQuickActionTap);
      
      // 3. NO mostrar notificación aún - esperar login
      // await NotificationService.showQuickActionNotification();
      
      _isInitialized = true;
      print('[SilentCoordinator] ✅ Servicios base inicializados (sin notificación)');
      
    } catch (e) {
      print('[SilentCoordinator] Error inicializando: $e');
      rethrow;
    }
  }

  /// Activa la funcionalidad silenciosa DESPUÉS del login exitoso
  static Future<void> activateAfterLogin() async {
    print('');
    print('=== ACTIVATE AFTER LOGIN CALLED ===');
    print('[SilentCoordinator] 🔓 MÉTODO activateAfterLogin() EJECUTÁNDOSE');
    
    if (!_isInitialized) {
      print('[SilentCoordinator] ⚠️ Servicios no inicializados, inicializando primero...');
      return;
    }
    
    try {
      print('[SilentCoordinator] 🔓 Usuario autenticado - Activando notificación persistente');
      
      // Mostrar notificación persistente ahora que el usuario está logueado
      await NotificationService.showQuickActionNotification();
      
      print('[SilentCoordinator] ✅ Funcionalidad silenciosa ACTIVADA después del login');
      
    } catch (e) {
      print('[SilentCoordinator] Error activando después del login: $e');
    }
  }

  /// Desactiva la funcionalidad silenciosa DESPUÉS del logout
  static Future<void> deactivateAfterLogout() async {
    print('');
    print('=== DEACTIVATE AFTER LOGOUT CALLED ===');
    print('[SilentCoordinator] 🔒 MÉTODO deactivateAfterLogout() EJECUTÁNDOSE');
    
    try {
      print('[SilentCoordinator] 🔒 Usuario deslogueado - Desactivando notificación persistente');
      
      // Cancelar la notificación persistente
      await NotificationService.cancelQuickActionNotification();
      
      print('[SilentCoordinator] ✅ Funcionalidad silenciosa DESACTIVADA después del logout');
      
    } catch (e) {
      print('[SilentCoordinator] Error desactivando después del logout: $e');
    }
  }

  static void _handleQuickActionTap() {
    print('[SilentCoordinator] 🎯 Tap en notificación detectado');
    
    if (_context == null || !_isInitialized) {
      print('[SilentCoordinator] ❌ Context no disponible o no inicializado');
      print('[SilentCoordinator] ❌ _context: $_context, _isInitialized: $_isInitialized');
      return;
    }

    if (!_context!.mounted) {
      print('[SilentCoordinator] ❌ Context no está mounted, buscando context válido...');
      return;
    }

    print('[SilentCoordinator] ✅ Abriendo modal de selección de estado');
    Navigator.of(_context!).push(
      PageRouteBuilder(
        opaque: false, // Permite transparencia
        pageBuilder: (context, animation, secondaryAnimation) {
          return StatusSelectorOverlay(
            onClose: () {
              print('[SilentCoordinator] Modal cerrado por usuario');
            },
          );
        },
      ),
    ).catchError((error) {
        print('[SilentCoordinator] ❌ Error al mostrar overlay');
        return null;
    });
  }

  /// Actualiza el contexto desde fuera del coordinador
  static void updateContext(BuildContext context) {
    _context = context;
  }

  /// Actualiza la notificación persistente cuando cambia el status
  static Future<void> updatePersistentNotification(StatusType? currentStatus) async {
    try {
      // Actualizar la notificación con el nuevo estado
      await NotificationService.showQuickActionNotification();
    } catch (e) {
      print('[SilentCoordinator] Error actualizando notificación: $e');
    }
  }

  /// Habilita/deshabilita la funcionalidad silenciosa
  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await NotificationService.showQuickActionNotification();
      await QuickActionsService.setEnabled(true);
    } else {
      await NotificationService.cancelQuickActionNotification();
      await QuickActionsService.setEnabled(false);
    }
  }

  /// Limpia recursos cuando la app se cierra
  static Future<void> dispose() async {
    await NotificationService.cancelQuickActionNotification();
    _isInitialized = false;
    _context = null;
  }
}