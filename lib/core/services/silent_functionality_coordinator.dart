import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../notifications/notification_service.dart';
import '../../quick_actions/quick_actions_service.dart';
import '../../services/circle_service.dart';
import 'status_modal_service.dart';
import 'status_service.dart';

/// Coordinador de Modo Silencio — interfaz mínima entre Flutter y Kotlin.
///
/// Flutter es responsable de:
///   - Verificar que el usuario pertenece a un círculo (_userHasCircle)
///   - Pedir permiso de notificaciones antes de activar
///   - Llamar activate() / deactivate() en el canal nativo
///
/// Kotlin (MainActivity + KeepAliveService) es responsable de:
///   - Estado isSilentModeActive
///   - Notificación persistente (via startForeground)
///   - moveTaskToBack() al activar
///   - Detener todo en onResume() cuando el usuario reabre la app
class SilentFunctionalityCoordinator {
  static const _channel = MethodChannel('zync/keep_alive');

  static bool _isInitialized = false;
  static bool _isManualLogoutInProgress = false;
  static bool _userHasCircle = false;

  // ---------------------------------------------------------------------------
  // Inicialización
  // ---------------------------------------------------------------------------

  /// Inicializa los servicios base. Llamar en main() antes de runApp().
  static Future<void> initializeServices() async {
    if (_isInitialized) return;
    try {
      await NotificationService.initialize();
      await QuickActionsService.initialize();
      await StatusModalService.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[SilentCoordinator] ❌ Error en initializeServices: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Ciclo de vida de sesión
  // ---------------------------------------------------------------------------

  /// Llamar después del login exitoso. Verifica círculo y habilita el botón.
  static Future<void> activateAfterLogin(BuildContext context) async {
    // Un login siempre cancela cualquier logout previo en el mismo proceso.
    _isManualLogoutInProgress = false;

    debugPrint('[SilentCoordinator][DBG] activateAfterLogin — initialized=$_isInitialized');
    if (!_isInitialized) return;

    try {
      final userCircle = await CircleService().getUserCircle();
      debugPrint('[SilentCoordinator][DBG] getUserCircle → ${userCircle != null ? "circle=${userCircle.name}" : "NULL (sin círculo)"}');
      if (userCircle == null) {
        _userHasCircle = false;
        return;
      }
      _userHasCircle = true;
      await StatusService.clearOfflineStatus();
      debugPrint('[SilentCoordinator][DBG] clearOfflineStatus → OK');
    } catch (e) {
      debugPrint('[SilentCoordinator][DBG] activateAfterLogin EXCEPCIÓN: $e');
    }
  }

  /// Sincroniza el estado del círculo desde App Resume.
  /// Si el usuario tiene círculo activo, también cancela cualquier flag de logout residual.
  static void syncCircleState({required bool hasCircle}) {
    _userHasCircle = hasCircle;
    if (hasCircle) _isManualLogoutInProgress = false;
  }

  /// Llamar desde el logout manual (Settings → Cerrar sesión / Eliminar cuenta).
  static Future<void> deactivateAfterLogout() async {
    if (_isManualLogoutInProgress) return; // guard duplicados
    _isManualLogoutInProgress = true;
    _userHasCircle = false;

    try {
      await _channel.invokeMethod('deactivate');
    } catch (e) {
      debugPrint('[SilentCoordinator] ⚠️ Error al desactivar en logout: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Modo Silencio — activación explícita por botón en InCircleView
  // ---------------------------------------------------------------------------

  /// Activa el Modo Silencio. Requiere permiso de notificaciones y círculo activo.
  /// Kotlin maneja el resto: notificación, KeepAlive y moveTaskToBack.
  static Future<void> activateSilentMode(BuildContext context) async {
    debugPrint('[SilentCoordinator][DBG] activateSilentMode → logout=$_isManualLogoutInProgress, circle=$_userHasCircle, mounted=${context.mounted}');
    if (_isManualLogoutInProgress) return;
    if (!_userHasCircle) return;
    if (!context.mounted) return;

    final hasPermission = await NotificationService.requestPermissions();
    debugPrint('[SilentCoordinator][DBG] requestPermissions → $hasPermission');
    if (!context.mounted) return;

    if (!hasPermission) {
      _showNotificationsDisabledInfo(context);
      return;
    }

    try {
      debugPrint('[SilentCoordinator][DBG] invokeMethod activate →');
      await _channel.invokeMethod('activate');
      debugPrint('[SilentCoordinator][DBG] activate → OK');
    } catch (e) {
      debugPrint('[SilentCoordinator][DBG] activate EXCEPCIÓN: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // UX — permisos denegados
  // ---------------------------------------------------------------------------

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
                'Modo Silencio requiere notificaciones.\n'
                'Puedes habilitarlas en Ajustes → Notificaciones.',
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
          },
        ),
      ),
    );
  }
}
