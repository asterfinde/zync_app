import '../features/circle/domain_old/entities/user_status.dart';
import 'quick_actions_service.dart';
import 'dart:developer';

class QuickActionsHandler {
  /// Maneja la lógica cuando se selecciona una quick action desde fuera de la app
  static Future<void> handleAction(String action) async {
    log('[QuickActionsHandler] Handling quick action: $action');
    
    try {
      // Obtener el StatusType correspondiente
      final statusType = _mapActionToStatusType(action);
      
      if (statusType != null) {
        // Usar el servicio de quick actions para manejar la actualización
        await QuickActionsService.handleQuickAction(action);
        
        log('[QuickActionsHandler] Quick action handled successfully: $action');
      } else {
        log('[QuickActionsHandler] Unknown action: $action');
      }
    } catch (e) {
      log('[QuickActionsHandler] Error handling action $action: $e');
    }
  }

  /// Mapea una acción string a StatusType
  static StatusType? _mapActionToStatusType(String action) {
    switch (action) {
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
      case 'happy':
        return StatusType.happy;
      case 'meeting':
        return StatusType.meeting;
      case 'sleepy':
        return StatusType.sleepy;
      case 'excited':
        return StatusType.excited;
      case 'thinking':
        return StatusType.thinking;
      case 'worried':
        return StatusType.worried;
      default:
        return null;
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
  static Map<String, String>? getActionInfo(String action) {
    final statusType = _mapActionToStatusType(action);
    if (statusType != null) {
      return {
        'emoji': statusType.emoji,
        'description': statusType.description,
        'iconName': statusType.iconName,
      };
    }
    return null;
  }

  /// Verifica si una acción es válida
  static bool isValidAction(String action) {
    return _mapActionToStatusType(action) != null;
  }
}