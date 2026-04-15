import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../notifications/notification_service.dart';
import '../../quick_actions/quick_actions_service.dart';
import '../../services/circle_service.dart';
import '../models/user_status.dart';
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
    debugPrint('[SilentCoordinator][DBG] activateSilentMode → logout=$_isManualLogoutInProgress, circle=$_userHasCircle, mounted=${context.mounted}');
    if (_isManualLogoutInProgress) return;
    if (!context.mounted) return;

    // Bug 2 fix: _userHasCircle puede ser false en cold start por race condition
    // (activateAfterLogin aún no terminó). Re-verificar desde Firebase antes de cancelar.
    if (!_userHasCircle) {
      try {
        final userCircle = await CircleService().getUserCircle();
        debugPrint('[SilentCoordinator][DBG] activateSilentMode — re-check circle → ${userCircle != null ? userCircle.name : "NULL"}');
        if (userCircle == null) return;
        _userHasCircle = true;
      } catch (e) {
        debugPrint('[SilentCoordinator][DBG] activateSilentMode — error re-checking circle: $e');
        return;
      }
    }

    if (!context.mounted) return;

    final hasPermission = await NotificationService.requestPermissions();
    debugPrint('[SilentCoordinator][DBG] requestPermissions → $hasPermission');
    if (!context.mounted) return;

    if (!hasPermission) {
      _showNotificationsDisabledInfo(context);
      return;
    }

    // N1.03 — Opción A: Leer statusType actual de circles/{circleId}/memberStatus/{uid}.
    // users/{uid} NO tiene campo statusType — el status vive en el doc del círculo.
    // Se pasa a Kotlin para persistir y restaurar en Firestore al reabrir la app.
    // Zonas controladas ('home','school','work','university') → fallback a 'fine';
    // el geofencing las corrige solo.
    const zoneControlledIds = {'home', 'school', 'work', 'university'};
    String? preSilentStatusType;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final circleId = userDoc.data()?['circleId'] as String?;
        if (circleId != null) {
          final circleDoc = await FirebaseFirestore.instance.collection('circles').doc(circleId).get();
          final memberStatus = circleDoc.data()?['memberStatus'] as Map<String, dynamic>?;
          final myStatus = memberStatus?[user.uid] as Map<String, dynamic>?;
          final rawId = myStatus?['statusType'] as String?;
          // Solo reemplazar por 'fine' si la zona está activamente configurada para
          // geofencing. Sin zona configurada, el emoji actúa como status manual normal.
          if (rawId != null && zoneControlledIds.contains(rawId)) {
            final zonesSnap = await FirebaseFirestore.instance
                .collection('circles')
                .doc(circleId)
                .collection('zones')
                .where('type', isEqualTo: rawId)
                .limit(1)
                .get();
            preSilentStatusType = zonesSnap.docs.isNotEmpty ? 'fine' : rawId;
          } else {
            preSilentStatusType = rawId;
          }
          debugPrint('[SilentCoordinator][DBG] Estado previo: $rawId → guardando: $preSilentStatusType');
        }
      }
    } catch (e) {
      debugPrint('[SilentCoordinator][DBG] Error leyendo estado previo: $e');
    }

    // Escribir 'do_not_disturb' en Firestore antes de que el isolate Dart muera.
    // Esto reemplaza el concepto "Desconectado": los miembros del círculo ven
    // 🔕 No molestar mientras el Modo Silencio está activo.
    final doNotDisturb = StatusType.fallbackPredefined.firstWhere((s) => s.id == 'do_not_disturb');
    await StatusService.updateUserStatus(doNotDisturb);
    debugPrint('[SilentCoordinator][DBG] do_not_disturb escrito en Firestore');

    if (!context.mounted) return;

    try {
      debugPrint('[SilentCoordinator][DBG] invokeMethod activate →');
      await _channel.invokeMethod('activate', {
        if (preSilentStatusType != null && preSilentStatusType != 'do_not_disturb')
          'preSilentStatusType': preSilentStatusType,
      });
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
