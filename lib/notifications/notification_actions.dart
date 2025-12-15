import '../core/services/status_service.dart';
import '../core/models/user_status.dart';
import '../core/services/emoji_service.dart';
import 'notification_service.dart';
import 'dart:developer';

class NotificationActions {
  /// Define y maneja las acciones disponibles desde las notificaciones
  /// Mapea action IDs a status IDs (nuevo sistema de 16 emojis)
  static const Map<String, String> actionStatusMap = {
    'status_leave': 'away', // Ausente (reemplazo de leave)
    'status_busy': 'busy', // Ocupado
    'status_fine': 'fine',
    'status_sad': 'do_not_disturb', // No molestar (reemplazo de sad)
    'status_ready': 'fine',
    'status_sos': 'sos', // SOS
  };

  /// Maneja la acción seleccionada desde una notificación
  static Future<void> onActionSelected(String action) async {
    log('[NotificationActions] Action selected: $action');

    try {
      final statusId = actionStatusMap[action];

      if (statusId != null) {
        // Cargar StatusType desde Firebase por ID
        final emojis = await EmojiService.getPredefinedEmojis();
        final statusType = emojis.firstWhere(
          (s) => s.id == statusId,
          orElse: () => StatusType.fallbackPredefined.first,
        );

        // Actualizar el estado usando el StatusService
        final result = await StatusService.updateUserStatus(statusType);

        if (result.isSuccess) {
          log('[NotificationActions] Status updated successfully: ${statusType.label}');

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
  static Future<StatusType?> getStatusTypeForAction(String action) async {
    final statusId = actionStatusMap[action];
    if (statusId == null) return null;

    try {
      final emojis = await EmojiService.getPredefinedEmojis();
      return emojis.firstWhere(
        (s) => s.id == statusId,
        orElse: () => StatusType.fallbackPredefined.first,
      );
    } catch (e) {
      log('[NotificationActions] Error loading status: $e');
      return StatusType.fallbackPredefined.first;
    }
  }

  /// Obtiene información legible para una acción
  static Future<Map<String, String>?> getActionInfo(String action) async {
    final statusType = await getStatusTypeForAction(action);
    if (statusType != null) {
      return {
        'emoji': statusType.emoji,
        'description': statusType.label,
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
    return 'status_${statusType.id}';
  }

  /// Obtiene todas las acciones con su información
  static Future<Map<String, Map<String, String>>> getAllActionsInfo() async {
    final result = <String, Map<String, String>>{};

    for (final action in actionStatusMap.keys) {
      final info = await getActionInfo(action);
      if (info != null) {
        result[action] = info;
      }
    }

    return result;
  }

  /// Muestra una notificación de error
  static Future<void> _showErrorNotification() async {
    try {
      final emojis = await EmojiService.getPredefinedEmojis();
      final errorStatus = emojis.firstWhere(
        (s) => s.id == 'do_not_disturb',
        orElse: () => StatusType.fallbackPredefined.first,
      );
      await NotificationService.showSilentNotification(errorStatus);
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
      log('[NotificationActions] Action configured: $action -> ${status.label}');
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
