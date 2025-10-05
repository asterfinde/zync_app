import 'package:quick_actions/quick_actions.dart';
import '../core/services/status_service.dart';
import '../features/circle/domain_old/entities/user_status.dart';
import 'dart:developer';

class QuickActionsService {
  static const QuickActions _quickActions = QuickActions();
  
  /// Inicializa las Quick Actions según el plan del MD
  static Future<void> initialize() async {
    await _setupQuickActions();
    await _setupQuickActionHandler();
  }

  /// Configura las 6 quick actions principales
  static Future<void> _setupQuickActions() async {
    await _quickActions.setShortcutItems([
      const ShortcutItem(
        type: 'leave',
        localizedTitle: '🚶‍♂️ Saliendo',
      ),
      const ShortcutItem(
        type: 'busy',
        localizedTitle: '🔥 Ocupado',
      ),
      const ShortcutItem(
        type: 'fine',
        localizedTitle: '😊 Bien',
      ),
      const ShortcutItem(
        type: 'sad',
        localizedTitle: '😢 Mal',
      ),
      const ShortcutItem(
        type: 'ready',
        localizedTitle: '✅ Listo',
      ),
      const ShortcutItem(
        type: 'sos',
        localizedTitle: '🆘 SOS',
      ),
    ]);
  }

  /// Configura el handler para cuando se selecciona una quick action
  static Future<void> _setupQuickActionHandler() async {
    _quickActions.initialize((String shortcutType) async {
      await handleQuickAction(shortcutType);
    });
  }

  /// Maneja la acción cuando se selecciona una quick action
  static Future<void> handleQuickAction(String actionType) async {
    log('[QuickActionsService] Quick action selected: $actionType');
    
    try {
      final statusType = _parseStatusType(actionType);
      if (statusType != null) {
        final result = await StatusService.updateUserStatus(statusType);
        if (result.isSuccess) {
          log('[QuickActionsService] Status updated successfully via quick action');
        } else {
          log('[QuickActionsService] Failed to update status: ${result.errorMessage}');
        }
      } else {
        log('[QuickActionsService] Unknown action type: $actionType');
      }
    } catch (e) {
      log('[QuickActionsService] Error handling quick action: $e');
    }
  }

  /// Convierte el string de acción a StatusType
  static StatusType? _parseStatusType(String actionType) {
    switch (actionType) {
      case 'leave':
        return StatusType.leave;
      case 'busy':
        return StatusType.busy;
      case 'fine':
        return StatusType.fine;
      case 'sad':
        return StatusType.sad;
      case 'ready':
        return StatusType.ready;
      case 'sos':
        return StatusType.sos;
      default:
        return null;
    }
  }

  /// Habilita o deshabilita las quick actions
  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _setupQuickActions();
    } else {
      await _quickActions.clearShortcutItems();
    }
  }

  /// Actualiza las quick actions con configuración personalizada
  static Future<void> updateQuickActions(List<StatusType> enabledStatuses) async {
    final shortcutItems = enabledStatuses.map((status) {
      return ShortcutItem(
        type: status.name,
        localizedTitle: status.description,
        icon: status.iconName,
      );
    }).toList();

    await _quickActions.setShortcutItems(shortcutItems);
  }
}