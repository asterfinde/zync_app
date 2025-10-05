import '../core/services/status_service.dart';
import '../features/circle/domain_old/entities/user_status.dart';
import 'notification_service.dart';
import 'dart:developer';

class NotificationActions {
  /// Define y maneja las acciones disponibles desde las notificaciones
  static const Map<String, StatusType> actionStatusMap = {
    'status_leave': StatusType.leave,
    'status_busy': StatusType.busy,
    'status_fine': StatusType.fine,
    'status_sad': StatusType.sad,
    'status_ready': StatusType.ready,
    'status_sos': StatusType.sos,
  };

  /// Maneja la acción seleccionada desde una notificación
  static Future<void> onActionSelected(String action) async {
    log('[NotificationActions] Action selected: $action');
    
    try {
      final statusType = actionStatusMap[action];
      
      if (statusType != null) {
        // Actualizar el estado usando el StatusService
        final result = await StatusService.updateUserStatus(statusType);
        
        if (result.isSuccess) {
          log('[NotificationActions] Status updated successfully: ${statusType.description}');
          
          // Mostrar notificación de confirmación
          await NotificationService.showSilentNotification(statusType);
        } else {
          log('[NotificationActions] Failed to update status: ${result.errorMessage}');
          await _showErrorNotification();
        }
      } else {
        log('[NotificationActions] Unknown action: $action');
      }
    } catch (e) {
      log('[NotificationActions] Error handling action $action: $e');
      await _showErrorNotification();
    }
  }

  /// Obtiene la lista de acciones disponibles
  static List<String> getAvailableActions() {
    return actionStatusMap.keys.toList();
  }

  /// Obtiene el StatusType para una acción específica
  static StatusType? getStatusTypeForAction(String action) {
    return actionStatusMap[action];
  }

  /// Obtiene información legible para una acción
  static Map<String, String>? getActionInfo(String action) {
    final statusType = actionStatusMap[action];
    if (statusType != null) {
      return {
        'emoji': statusType.emoji,
        'description': statusType.description,
        'action': action,
      };
    }
    return null;
  }

  /// Verifica si una acción es válida
  static bool isValidAction(String action) {
    return actionStatusMap.containsKey(action);
  }

  /// Crea una acción personalizada
  static String createCustomAction(StatusType statusType) {
    return 'status_${statusType.name}';
  }

  /// Obtiene todas las acciones con su información
  static Map<String, Map<String, String>> getAllActionsInfo() {
    final result = <String, Map<String, String>>{};
    
    for (final action in actionStatusMap.keys) {
      final info = getActionInfo(action);
      if (info != null) {
        result[action] = info;
      }
    }
    
    return result;
  }

  /// Muestra una notificación de error
  static Future<void> _showErrorNotification() async {
    try {
      await NotificationService.showSilentNotification(StatusType.worried);
    } catch (e) {
      log('[NotificationActions] Error showing error notification: $e');
    }
  }

  /// Configura las acciones según las preferencias del usuario
  static Future<void> configureActions(List<StatusType> enabledStatuses) async {
    log('[NotificationActions] Configuring actions for ${enabledStatuses.length} statuses');
    
    // Esta funcionalidad se puede expandir para personalizar
    // las acciones disponibles según las preferencias del usuario
    
    // Por ahora, simplemente logueamos la configuración
    for (final status in enabledStatuses) {
      final action = createCustomAction(status);
      log('[NotificationActions] Action configured: $action -> ${status.description}');
    }
  }

  /// Handler global para todas las acciones de notificaciones
  /// Este método debe ser llamado desde el NotificationService cuando se reciba una acción
  static Future<void> handleGlobalAction(String actionId) async {
    if (isValidAction(actionId)) {
      await onActionSelected(actionId);
    } else {
      log('[NotificationActions] Received invalid action: $actionId');
    }
  }
}