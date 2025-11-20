import 'package:quick_actions/quick_actions.dart';
import '../core/services/status_service.dart';
import '../core/services/quick_actions_preferences_service.dart';
import '../core/models/user_status.dart';
import 'dart:developer';

class QuickActionsService {
  static const QuickActions _quickActions = QuickActions();
  
  /// Inicializa las Quick Actions según las preferencias del usuario
  static Future<void> initialize() async {
    await _setupQuickActions();
    await _setupQuickActionHandler();
  }

  /// Configura las Quick Actions según las preferencias del usuario (Point 14)
  /// Permite hasta 4 emojis personalizables por el usuario
  static Future<void> _setupQuickActions() async {
    try {
      // Obtener las 4 Quick Actions configuradas por el usuario
      final userQuickActions = await QuickActionsPreferencesService.getUserQuickActions();
      
      // Convertir a ShortcutItems
      final shortcutItems = userQuickActions.map((status) {
        return ShortcutItem(
          type: status.toString().split('.').last, // 'available', 'busy', etc.
          localizedTitle: '${status.emoji} ${status.description}',
        );
      }).toList();
      
      await _quickActions.setShortcutItems(shortcutItems);
      
      log('[QuickActionsService] ✅ Quick Actions configuradas: ${userQuickActions.map((s) => s.emoji).join(', ')}');
      
    } catch (e) {
      log('[QuickActionsService] ❌ Error configurando Quick Actions: $e');
      // Fallback a configuración por defecto en caso de error
      await _setupDefaultQuickActions();
    }
  }
  
  /// Configuración de fallback con Quick Actions por defecto
  static Future<void> _setupDefaultQuickActions() async {
    await _quickActions.setShortcutItems([
      const ShortcutItem(
        type: 'available',
        localizedTitle: '� Disponible',
      ),
      const ShortcutItem(
        type: 'busy',
        localizedTitle: '� Ocupado',
      ),
      const ShortcutItem(
        type: 'away',
        localizedTitle: '🟡 Ausente',
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

  /// Convierte el string de acción a StatusType (actualizado para Point 14)
  /// Soporta todos los StatusType disponibles, no solo los 6 legacy
  static StatusType? _parseStatusType(String actionType) {
    try {
      // Buscar el StatusType que coincida con el actionType
      return StatusType.values.firstWhere(
        (status) => status.toString().split('.').last == actionType,
      );
    } catch (e) {
      log('[QuickActionsService] ❌ StatusType no encontrado: $actionType');
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

  /// Actualiza las Quick Actions cuando el usuario cambia su configuración
  /// Point 14: Permite configuración personalizada de 4 Quick Actions
  static Future<void> updateUserQuickActions(List<StatusType> newQuickActions) async {
    try {
      if (newQuickActions.length != 4) {
        log('[QuickActionsService] ❌ Error: Debe haber exactamente 4 Quick Actions');
        return;
      }
      
      // Guardar las nuevas preferencias
      final saved = await QuickActionsPreferencesService.saveUserQuickActions(newQuickActions);
      
      if (saved) {
        // Actualizar las Quick Actions del sistema
        await _setupQuickActions();
        log('[QuickActionsService] ✅ Quick Actions actualizadas por el usuario');
      } else {
        log('[QuickActionsService] ❌ Error guardando preferencias de Quick Actions');
      }
      
    } catch (e) {
      log('[QuickActionsService] ❌ Error actualizando Quick Actions: $e');
    }
  }

  /// Método legacy mantenido para compatibilidad
  static Future<void> updateQuickActions(List<StatusType> enabledStatuses) async {
    await updateUserQuickActions(enabledStatuses);
  }
}