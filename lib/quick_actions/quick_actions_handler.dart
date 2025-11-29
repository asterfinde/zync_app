import '../core/models/user_status.dart';
import '../core/services/status_service.dart';
import '../core/services/emoji_service.dart';
import 'dart:developer';

class QuickActionsHandler {
  /// Maneja la lógica cuando se selecciona una quick action desde fuera de la app
  static Future<void> handleAction(String action) async {
    log('[QuickActionsHandler] Handling quick action: $action');

    try {
      // Obtener el StatusType correspondiente
      final statusType = await _mapActionToStatusType(action);

      if (statusType != null) {
        // Actualizar estado directamente usando StatusService
        final result = await StatusService.updateUserStatus(statusType);

        if (result.isSuccess) {
          log('[QuickActionsHandler] Quick action handled successfully: $action');
        } else {
          log('[QuickActionsHandler] Error updating status: ${result.errorMessage}');
        }
      } else {
        log('[QuickActionsHandler] Unknown action: $action');
      }
    } catch (e) {
      log('[QuickActionsHandler] Error handling action $action: $e');
    }
  }

  /// Mapea una acción string a StatusType (carga desde Firebase)
  /// Mapeo de IDs antiguos a nuevos:
  /// - leave → away
  /// - fine → available
  /// - sad, sleepy, worried, thinking, excited → do_not_disturb (estados eliminados)
  /// - busy, sos, meeting → sin cambios
  static Future<StatusType?> _mapActionToStatusType(String action) async {
    // Mapeo de action IDs a status IDs del nuevo sistema
    final String? statusId;
    switch (action) {
      case 'leave':
        statusId = 'away'; // Ausente (reemplazo de leave)
        break;
      case 'busy':
        statusId = 'busy'; // Ocupado
        break;
      case 'fine':
        statusId = 'available'; // Disponible (reemplazo de fine)
        break;
      case 'sad':
      case 'worried':
      case 'sleepy':
      case 'excited':
      case 'thinking':
        statusId =
            'do_not_disturb'; // No molestar (reemplazo de estados emocionales)
        break;
      case 'ready':
        statusId = 'available'; // Disponible (reemplazo de ready)
        break;
      case 'sos':
        statusId = 'sos'; // SOS
        break;
      case 'happy':
        statusId = 'available'; // Disponible (reemplazo de happy)
        break;
      case 'meeting':
        statusId = 'meeting'; // Reunión
        break;
      default:
        statusId = null;
    }

    if (statusId == null) return null;

    try {
      final emojis = await EmojiService.getPredefinedEmojis();
      return emojis.firstWhere(
        (s) => s.id == statusId,
        orElse: () => StatusType.fallbackPredefined.first,
      );
    } catch (e) {
      log('[QuickActionsHandler] Error loading status: $e');
      return StatusType.fallbackPredefined.first;
    }
  }

  /// Obtiene la lista de acciones disponibles
  static List<String> getAvailableActions() {
    return [
      'leave',
      'busy',
      'fine',
      'sad',
      'ready',
      'sos',
    ];
  }

  /// Obtiene la información de una acción específica
  static Future<Map<String, String>?> getActionInfo(String action) async {
    final statusType = await _mapActionToStatusType(action);
    if (statusType != null) {
      return {
        'emoji': statusType.emoji,
        'description': statusType.label,
        'iconName': statusType.emoji, // Usamos emoji como iconName
      };
    }
    return null;
  }

  /// Verifica si una acción es válida
  static Future<bool> isValidAction(String action) async {
    return await _mapActionToStatusType(action) != null;
  }
}
