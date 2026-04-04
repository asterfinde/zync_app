import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Point 21: Para MethodChannel
import '../../notifications/notification_service.dart';
import '../../quick_actions/quick_actions_service.dart';
import '../../widgets/notification_status_selector.dart'; // CAMBIADO: Usar modal de notificaciones
import '../../core/models/user_status.dart';
import '../../services/circle_service.dart';
import 'status_modal_service.dart';

/// Coordinador de funcionalidad silenciosa - Integra sin romper lo existente
class SilentFunctionalityCoordinator {
  static bool _isInitialized = false;
  static BuildContext? _context;
  static bool _isManualLogoutInProgress = false; // Point 1.1: Bandera para evitar reactivación
  static bool _userHasCircle = false; // True solo cuando activateAfterLogin confirmó círculo activo

  /// Inicializa SOLO los servicios base (sin BuildContext)
  /// Se debe llamar en main() ANTES de runApp()
  static Future<void> initializeServices() async {
    print('');
    print('=== SILENT COORDINATOR INITIALIZE SERVICES CALLED ===');
    print('[SilentCoordinator] 🚀 INICIO initializeServices() - _isInitialized: $_isInitialized');
    if (_isInitialized) {
      print('[SilentCoordinator] ⚠️ Ya está inicializado, saliendo...');
      return;
    }

    try {
      // 1. Inicializar servicios existentes (sin romper nada)
      print('[SilentCoordinator] 🔧 Inicializando servicios base...');

      await NotificationService.initialize();
      await QuickActionsService.initialize();

      // Point 15: Inicializar servicio del modal transparente
      await StatusModalService.initialize();

      // 2. Configurar el handler para la notificación persistente
      NotificationService.setQuickActionTapHandler(_handleQuickActionTap);

      // 3. NO mostrar notificación aún - esperar login
      // await NotificationService.showQuickActionNotification();

      _isInitialized = true;
      print('[SilentCoordinator] ✅ Servicios base inicializados exitosamente');
    } catch (e) {
      print('[SilentCoordinator] ❌ Error inicializando servicios: $e');
      rethrow;
    }
  }

  /// Inicializa toda la funcionalidad silenciosa con BuildContext
  /// DEPRECADO: Usar initializeServices() en main() + setContext() después
  static Future<void> initialize(BuildContext context) async {
    print('[SilentCoordinator] ⚠️ initialize() con BuildContext es deprecado');
    _context = context;

    if (!_isInitialized) {
      await initializeServices();
    }
  }

  /// Activa la funcionalidad silenciosa DESPUÉS del login exitoso
  /// SOLO si el usuario pertenece a un círculo
  static Future<void> activateAfterLogin(BuildContext context) async {
    print('');
    print('=== ACTIVATE AFTER LOGIN CALLED ===');
    print('[SilentCoordinator] 🔓 MÉTODO activateAfterLogin() EJECUTÁNDOSE');

    // Point 1.1: NO activar si hay un logout manual en progreso
    if (_isManualLogoutInProgress) {
      print('[SilentCoordinator] ⚠️ Logout manual en progreso - BLOQUEANDO activación');
      return;
    }

    _context = context;

    if (!_isInitialized) {
      print('[SilentCoordinator] ❌ ERROR: Servicios NO inicializados');
      print('[SilentCoordinator] ❌ Debes llamar initializeServices() en main() antes de runApp()');
      return;
    }

    try {
      // VERIFICAR SI EL USUARIO PERTENECE A UN CÍRCULO
      print('[SilentCoordinator] 🔍 Verificando pertenencia a círculo...');
      final circleService = CircleService();
      final userCircle = await circleService.getUserCircle();

      if (userCircle == null) {
        print('[SilentCoordinator] ⚠️ Usuario NO pertenece a un círculo');
        print('[SilentCoordinator] ⚠️ NO se solicitarán permisos de notificación');
        print('[SilentCoordinator] 💡 Las notificaciones se activarán cuando se una a un círculo');
        return;
      }

      print('[SilentCoordinator] ✅ Usuario pertenece al círculo: ${userCircle.name}');
      _userHasCircle = true;

      final hasPermission = await NotificationService.requestPermissions();

      if (hasPermission) {
        print('[SilentCoordinator] ✅ Permisos de notificación otorgados');
        print('[SilentCoordinator] Mostrando notificación persistente...');
        await NotificationService.showQuickActionNotification();
        print('[SilentCoordinator] ✅ Funcionalidad silenciosa ACTIVADA');

        // Point 1.1: Resetear bandera de logout manual (usuario hizo login exitoso)
        _isManualLogoutInProgress = false;
        print('[SilentCoordinator] 🔓 Bandera Dart de logout manual RESETEADA');

        // Point 1.1: Resetear también en el lado NATIVO
        try {
          const keepAliveChannel = MethodChannel('zync/keep_alive');
          await keepAliveChannel.invokeMethod('setManualLogoutFlag', {'inProgress': false});
          print('[SilentCoordinator] 🔓 Bandera nativa de logout RESETEADA');
        } catch (e) {
          print('[SilentCoordinator] ⚠️ Error reseteando bandera nativa: $e');
        }
      } else {
        print('[SilentCoordinator] ⚠️ Permisos de notificación denegados');
        print('[SilentCoordinator] 💡 Point 2: El modal se mostrará después de navegar a HomePage');
        // Point 2: NO mostrar modal aquí - se mostrará en auth_final_page después de navegar
      }
    } catch (e) {
      print('[SilentCoordinator] ❌ Error solicitando permisos: $e');
    }

    print('');
  }

  /// Point 21 FASE 5: Muestra diálogo cuando las notificaciones están bloqueadas
  // TODO: Implementar cuando se active la validación de permisos
  /* static void _showNotificationPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Usuario debe tomar acción
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Notificaciones Bloqueadas'),
          ],
        ),
        content: const Text(
          'Para usar la función de cambio rápido de estado, '
          'necesitas habilitar las notificaciones.\n\n'
          '¿Quieres abrir la configuración ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              print('[SilentCoordinator] 🚫 Usuario omitió habilitar notificaciones');
              _showNotificationsDisabledInfo(context);
            },
            child: const Text('Ahora No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              print('[SilentCoordinator] 🔧 Abriendo Settings de Android...');
              await NotificationService.openNotificationSettings();
              
              // FASE 5 UX: Esperar un momento y verificar si habilitó notificaciones
              await Future.delayed(const Duration(seconds: 2));
              await _checkAndNotifyPermissionStatus(context);
            },
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }
  */
  /// FASE 5 UX: Verifica el estado de permisos después de que el usuario vuelve de Settings
  static Future<void> _checkAndNotifyPermissionStatus(BuildContext context) async {
    if (!context.mounted) return;

    try {
      final hasPermission = await NotificationService.hasPermission();

      if (hasPermission) {
        print('[SilentCoordinator] ✅ Usuario habilitó notificaciones - mostrando notificación');
        await NotificationService.showQuickActionNotification();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Notificaciones habilitadas - Cambio rápido disponible'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('[SilentCoordinator] ⚠️ Usuario NO habilitó notificaciones');
        _showNotificationsDisabledInfo(context);
      }
    } catch (e) {
      print('[SilentCoordinator] ❌ Error verificando permisos: $e');
    }
  }

  /// FASE 5 UX: Muestra mensaje informativo cuando notificaciones están deshabilitadas
  static void _showNotificationsDisabledInfo(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cambio rápido no disponible sin notificaciones.\n'
                'Puedes habilitarlas en Settings → Notificaciones.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Habilitar',
          textColor: Colors.white,
          onPressed: () async {
            await NotificationService.openNotificationSettings();
            await Future.delayed(const Duration(seconds: 2));
            if (context.mounted) {
              await _checkAndNotifyPermissionStatus(context);
            }
          },
        ),
      ),
    );
  }

  /// Desactiva la funcionalidad silenciosa DESPUÉS del logout
  /// ⚠️ IMPORTANTE (Point 1.1): Este método SOLO debe llamarse desde LOGOUT MANUAL en Settings
  /// NO debe llamarse automáticamente desde AuthWrapper ni otros lugares
  static Future<void> deactivateAfterLogout() async {
    print('');
    print('=== DEACTIVATE AFTER LOGOUT CALLED ===');
    print('[SilentCoordinator] 🔒 MÉTODO deactivateAfterLogout() EJECUTÁNDOSE');

    // Guard: si ya hay un logout en progreso, ignorar llamada duplicada.
    // Evita que auth_provider u otros listeners disparen una segunda limpieza
    // mientras deleteAccount() ya está ejecutando la primera.
    if (_isManualLogoutInProgress) {
      print('[SilentCoordinator] ⚠️ Logout ya en progreso — llamada duplicada ignorada');
      return;
    }

    // Point 1.1: Marcar que hay un logout manual en progreso (Dart)
    _isManualLogoutInProgress = true;
    _userHasCircle = false;

    // Point 1.1: Marcar también en el lado NATIVO (Android)
    try {
      const keepAliveChannel = MethodChannel('zync/keep_alive');
      await keepAliveChannel.invokeMethod('setManualLogoutFlag', {'inProgress': true});
      print('[SilentCoordinator] 🔒 Bandera nativa de logout activada');
    } catch (e) {
      print('[SilentCoordinator] ⚠️ Error activando bandera nativa: $e');
    }

    try {
      // Point 1.1: Limpieza exhaustiva - ORDEN CRÍTICO
      print('[SilentCoordinator] 🔒 Usuario deslogueado - Iniciando limpieza...');

      // PASO 1: Detener KeepAliveService PRIMERO (esto auto-cancela su notificación en onDestroy)
      print('[SilentCoordinator] PASO 1/3: Deteniendo KeepAliveService...');
      try {
        const keepAliveChannel = MethodChannel('zync/keep_alive');
        await keepAliveChannel.invokeMethod('stop');
        print('[SilentCoordinator] ✅ KeepAliveService.stop() llamado');
      } catch (e) {
        print('[SilentCoordinator] ❌ Error deteniendo KeepAliveService: $e');
      }

      // PASO 2: Esperar más tiempo para que onDestroy() se ejecute completamente
      print('[SilentCoordinator] PASO 2/3: Esperando 1.5 segundos para que onDestroy complete...');
      await Future.delayed(const Duration(milliseconds: 1500));

      // PASO 3: Cancelar TODAS las notificaciones restantes (limpieza final)
      print('[SilentCoordinator] PASO 3/3: Cancelación final de notificaciones restantes...');
      await NotificationService.cancelAllNotificationsAggressive();

      print('[SilentCoordinator] ✅ Proceso de limpieza completado');
      print('[SilentCoordinator] ✅ KeepAliveService destruido + Notificaciones canceladas');

      // Point 1.1: Mantener la bandera activa para evitar reactivación por AuthWrapper
      // Se reseteará solo cuando el usuario haga login nuevamente
      print('[SilentCoordinator] 🔒 Bandera de logout manual ACTIVA - bloqueará reactivaciones');
    } catch (e) {
      print('[SilentCoordinator] ❌ Error en proceso de limpieza: $e');
      // Resetear bandera si hubo error para permitir reintentos
      _isManualLogoutInProgress = false;
    }
  }

  /// Point 21 FASE 5: Abrir modal SIN abrir la app completa
  /// Usa StatusModalActivity nativa para comportamiento transparente
  static void _handleQuickActionTap() async {
    print('[SilentCoordinator] 🎯 Tap en notificación detectado - FASE 5');

    if (!_isInitialized) {
      print('[SilentCoordinator] ❌ No inicializado');
      return;
    }

    try {
      print('[SilentCoordinator] 🚀 Abriendo StatusModalActivity (modal transparente)...');

      // FASE 5: Abrir activity nativa transparente en lugar de usar Navigator
      // Esto evita abrir la app completa
      await StatusModalService.openModal();

      print('[SilentCoordinator] ✅ StatusModalActivity iniciada');
    } catch (e) {
      print('[SilentCoordinator] ❌ Error abriendo modal transparente: $e');
      print('[SilentCoordinator] 🚨 Fallback: Intentando abrir con Navigator...');

      // Fallback: usar el método anterior si falla
      if (_context != null && _context!.mounted) {
        Navigator.of(_context!)
            .push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, animation, secondaryAnimation) {
              return NotificationStatusSelector(
                // CAMBIADO: Usar modal de notificaciones
                onClose: () {
                  print('[SilentCoordinator] Modal cerrado por usuario');
                },
              );
            },
          ),
        )
            .catchError((error) {
          print('[SilentCoordinator] ❌ Error en fallback: $error');
          return null;
        });
      }
    }
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

  /// Verifica el estado de permisos al volver al frente o al llegar a HomePage.
  /// - Sin permiso: muestra SnackBar con botón "Habilitar" (T4.6, T4.9)
  /// - Con permiso: garantiza que la notificación persistente esté activa (T4.11)
  /// Solo actúa si el usuario tiene círculo activo.
  static Future<void> onAppResumed(BuildContext context) async {
    if (_isManualLogoutInProgress) return;
    if (!_userHasCircle) return;
    if (!context.mounted) return;

    final hasPermission = await NotificationService.hasPermission();

    if (!context.mounted) return;

    if (!hasPermission) {
      _showNotificationsDisabledInfo(context);
    } else {
      await NotificationService.showQuickActionNotification();
    }
  }

  /// Limpia recursos cuando la app se cierra
  static Future<void> dispose() async {
    await NotificationService.cancelQuickActionNotification();
    _isInitialized = false;
    _context = null;
  }
}
