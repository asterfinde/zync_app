import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../notifications/notification_service.dart';
import '../../quick_actions/quick_actions_service.dart';
import '../../services/circle_service.dart';
import 'status_modal_service.dart';

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
///   - Detener todo en onCreate() cuando el usuario reabre la app (Regla 1)
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
      // El último estado se preserva en Firestore — no se resetea a 'fine'.
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
    if (_isManualLogoutInProgress) return;
    if (!context.mounted) return;

    // Bug 2 fix: _userHasCircle puede ser false en cold start por race condition
    // (activateAfterLogin aún no terminó). Re-verificar desde Firebase antes de cancelar.
    if (!_userHasCircle) {
      try {
        final userCircle = await CircleService().getUserCircle();
        if (userCircle == null) return;
        _userHasCircle = true;
      } catch (e) {
        debugPrint('[SilentCoordinator] ❌ Firebase re-check ERROR: $e');
        return;
      }
    }

    if (!context.mounted) return;

    final hasPermission = await NotificationService.requestPermissions();
    if (!context.mounted) return;

    if (!hasPermission) {
      _showNotificationsDisabledInfo(context);
      return;
    }

    if (!context.mounted) return;

    // ════════════════════════════════════════════════════════════
    // [FIX] Persistir estado pre-silencio antes de activar
    // Fecha: 2026-05-05
    // PROBLEMA: Tras ~12h en background, el Worker sobreescribe
    //           flutter.manual_status_id con otro status. Al abrir
    //           el modal en Modo Silencio, el testigo muestra emoji incorrecto.
    // SOLUCIÓN: Guardar manual_status_id → pre_silent_status_id antes de
    //           invocar 'activate'. in_circle_view lee pre_silent_status_id
    //           cuando is_silent_mode_active == true.
    // ════════════════════════════════════════════════════════════
    try {
      final prefs = await SharedPreferences.getInstance();
      final manualId = prefs.getString('manual_status_id');
      if (manualId != null) {
        await prefs.setString('pre_silent_status_id', manualId);
        debugPrint('[SilentCoordinator] 💾 pre_silent_status_id guardado: $manualId');
      }
      await prefs.setBool('is_silent_mode_active', true);
      debugPrint('[SilentCoordinator] 💾 is_silent_mode_active=true guardado en Flutter SharedPreferences');
    } catch (e) {
      debugPrint('[SilentCoordinator] ⚠️ Error guardando pre_silent_status_id: $e');
    }

    try {
      await _channel.invokeMethod('activate');
    } catch (e) {
      debugPrint('[SilentCoordinator] ❌ activate EXCEPCIÓN: $e');
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
