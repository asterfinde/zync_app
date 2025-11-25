import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
// TODO: Migrar a launcher_shortcuts
// import 'package:quick_actions/quick_actions.dart';
import '../../core/models/user_status.dart';
import '../services/status_service.dart';

/// Widget service for handling home screen widgets and quick actions
/// NOTA: Quick Actions movidos a QuickActionsService (launcher_shortcuts)
class StatusWidgetService {
  static const String _widgetName = 'ZyncStatusWidget';
  static const String _statusKey = 'status';
  static const String _circleKey = 'circle';

  // Quick action identifiers (DEPRECATED - usar QuickActionsService)
  static const String _quickActionHappy = 'happy';
  static const String _quickActionSad = 'sad';
  static const String _quickActionBusy = 'busy';
  static const String _quickActionReady = 'ready';

  // static final QuickActions _quickActions = QuickActions(); // DEPRECATED

  /// Initialize the widget service
  static Future<void> initialize() async {
    try {
      // await _setupQuickActions(); // DEPRECATED - usar QuickActionsService
      await _setupWidget();
    } catch (e) {
      debugPrint('🔴 [StatusWidgetService] Error durante inicialización: $e');
    }
  }

  /// Setup quick actions for the app (DEPRECATED - usar QuickActionsService)
  /*
  static Future<void> _setupQuickActions() async {
    try {
      await _quickActions.initialize((String shortcutType) {
        _handleQuickAction(shortcutType);
      });
      
      await _quickActions.setShortcutItems([
        const ShortcutItem(
          type: _quickActionHappy,
          localizedTitle: '� Feliz',
          icon: 'icon_happy',
        ),
        const ShortcutItem(
          type: _quickActionSad,
          localizedTitle: '😢 Mal',
          icon: 'icon_sad',
        ),
        const ShortcutItem(
          type: _quickActionBusy,
          localizedTitle: '� Ocupado',
          icon: 'icon_busy',
        ),
        const ShortcutItem(
          type: _quickActionReady,
          localizedTitle: '✅ Listo',
          icon: 'icon_ready',
        ),
      ]);
      
      debugPrint('✅ [StatusWidgetService] Quick actions configuradas');
    } catch (e) {
      debugPrint('🔴 [StatusWidgetService] Error configurando quick actions: $e');
    }
  }
  */

  /// Setup home screen widget
  static Future<void> _setupWidget() async {
    try {
      await HomeWidget.setAppGroupId('group.com.datainfers.zync');
      await _updateWidget(status: StatusType.fine, circleId: null);
      debugPrint('✅ [StatusWidgetService] Widget configurado');
    } catch (e) {
      debugPrint('🔴 [StatusWidgetService] Error configurando widget: $e');
    }
  }

  /// Handle quick action selection
  static void _handleQuickAction(String actionType) {
    debugPrint('🚀 [StatusWidgetService] Quick action triggered: $actionType');

    StatusType statusType;
    switch (actionType) {
      case _quickActionHappy:
        statusType = StatusType.happy;
        break;
      case _quickActionSad:
        statusType = StatusType.sad;
        break;
      case _quickActionBusy:
        statusType = StatusType.busy;
        break;
      case _quickActionReady:
        statusType = StatusType.ready;
        break;
      default:
        debugPrint(
            '🔴 [StatusWidgetService] Acción no reconocida: $actionType');
        return;
    }

    _updateStatusSilently(statusType);
  }

  /// Update status silently (without opening the app)
  static Future<void> _updateStatusSilently(StatusType statusType) async {
    try {
      debugPrint(
          '🔄 [StatusWidgetService] Actualizando estado silenciosamente: ${statusType.emoji}');

      // Update status using our service
      final result = await StatusService.updateUserStatus(statusType);

      if (result.isSuccess) {
        // Update widget UI
        await _updateWidget(
          status: statusType,
          circleId: 'active', // We'll track the active circle later
        );

        // Show local notification
        await _showNotification(
          'Estado actualizado',
          'Tu estado cambió a ${statusType.emoji} ${statusType.description}',
        );

        debugPrint(
            '✅ [StatusWidgetService] Estado actualizado silenciosamente');
      } else {
        debugPrint(
            '🔴 [StatusWidgetService] Error actualizando estado: ${result.errorMessage}');
        await _showNotification(
          'Error',
          'No se pudo actualizar el estado: ${result.errorMessage}',
        );
      }
    } catch (e) {
      debugPrint(
          '🔴 [StatusWidgetService] Error en actualización silenciosa: $e');
      await _showNotification(
        'Error',
        'Error inesperado al actualizar estado',
      );
    }
  }

  /// Update the home screen widget display
  static Future<void> _updateWidget({
    required StatusType status,
    String? circleId,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(_statusKey, status.emoji);
      await HomeWidget.saveWidgetData<String>(
          _circleKey, circleId ?? 'Sin círculo');
      await HomeWidget.updateWidget(
        name: _widgetName,
        iOSName: _widgetName,
        androidName: _widgetName,
      );

      debugPrint('✅ [StatusWidgetService] Widget actualizado: ${status.emoji}');
    } catch (e) {
      debugPrint('🔴 [StatusWidgetService] Error actualizando widget: $e');
    }
  }

  /// Show a local notification
  static Future<void> _showNotification(String title, String body) async {
    try {
      // This will be implemented with flutter_local_notifications
      // For now, just log it
      debugPrint('📱 [StatusWidgetService] Notificación: $title - $body');
    } catch (e) {
      debugPrint('🔴 [StatusWidgetService] Error mostrando notificación: $e');
    }
  }

  /// Update widget when status changes from within the app
  static Future<void> onStatusChanged({
    required StatusType status,
    String? circleId,
  }) async {
    await _updateWidget(status: status, circleId: circleId);
  }
}
