import 'package:shared_preferences/shared_preferences.dart';
import '../../features/circle/domain_old/entities/user_status.dart';
import 'dart:convert';
import 'dart:developer';

/// Servicio para manejar las preferencias de Quick Actions del usuario
/// Permite seleccionar y guardar hasta 4 StatusTypes favoritos para Quick Actions
class QuickActionsPreferencesService {
  static const String _prefsKey = 'quick_actions_preferences';
  
  /// Quick Actions por defecto (las 4 más comunes)
  static final List<StatusType> _defaultQuickActions = [
    StatusType.available,  // 🟢 Disponible
    StatusType.busy,       // 🔴 Ocupado  
    StatusType.away,       // 🟡 Ausente
    StatusType.sos,        // 🆘 SOS
  ];

  /// Obtiene las Quick Actions configuradas por el usuario
  /// Si no hay configuración, devuelve las 4 por defecto
  static Future<List<StatusType>> getUserQuickActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_prefsKey);
      
      if (savedData != null) {
        final List<dynamic> savedList = json.decode(savedData);
        final List<StatusType> quickActions = [];
        
        // Convertir strings guardados de vuelta a StatusType
        for (String statusName in savedList) {
          try {
            final statusType = StatusType.values.firstWhere(
              (s) => s.toString().split('.').last == statusName,
            );
            quickActions.add(statusType);
          } catch (e) {
            log('[QuickActionsPrefs] Status no encontrado: $statusName');
          }
        }
        
        // Validar que tenemos exactamente 4 elementos válidos
        if (quickActions.length == 4) {
          log('[QuickActionsPrefs] ✅ Quick Actions cargadas: ${quickActions.map((s) => s.emoji).join(', ')}');
          return quickActions;
        }
      }
      
      // Si no hay configuración válida, usar defaults
      log('[QuickActionsPrefs] 🔧 Usando Quick Actions por defecto');
      return _defaultQuickActions;
      
    } catch (e) {
      log('[QuickActionsPrefs] ❌ Error cargando preferencias: $e');
      return _defaultQuickActions;
    }
  }

  /// Guarda la configuración de Quick Actions del usuario
  /// Debe recibir exactamente 4 StatusTypes
  static Future<bool> saveUserQuickActions(List<StatusType> quickActions) async {
    try {
      if (quickActions.length != 4) {
        log('[QuickActionsPrefs] ❌ Error: Debe haber exactamente 4 Quick Actions');
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Convertir StatusTypes a strings para guardar
      final List<String> statusNames = quickActions
          .map((status) => status.toString().split('.').last)
          .toList();
      
      final savedData = json.encode(statusNames);
      final success = await prefs.setString(_prefsKey, savedData);
      
      if (success) {
        log('[QuickActionsPrefs] ✅ Quick Actions guardadas: ${quickActions.map((s) => s.emoji).join(', ')}');
      }
      
      return success;
      
    } catch (e) {
      log('[QuickActionsPrefs] ❌ Error guardando preferencias: $e');
      return false;
    }
  }

  /// Resetea las Quick Actions a los valores por defecto
  static Future<bool> resetToDefaults() async {
    try {
      final success = await saveUserQuickActions(_defaultQuickActions);
      log('[QuickActionsPrefs] 🔄 Quick Actions reseteadas a defaults');
      return success;
    } catch (e) {
      log('[QuickActionsPrefs] ❌ Error reseteando: $e');
      return false;
    }
  }

  /// Obtiene todos los StatusTypes disponibles para Quick Actions
  /// SINCRONIZADO con StatusSelectorOverlay - Solo los 13 elementos del modal principal
  static List<StatusType> getAvailableStatusTypes() {
    // EXACTAMENTE los mismos elementos que StatusSelectorOverlay (Point 14 grid consistency fix)
    return [
      // Fila 1: Estados de disponibilidad básica
      StatusType.available, StatusType.busy, StatusType.away, StatusType.focus,
      // Fila 2: Estados emocionales/físicos  
      StatusType.happy, StatusType.tired, StatusType.stressed, StatusType.sad,
      // Fila 3: Estados de actividad/ubicación
      StatusType.traveling, StatusType.meeting, StatusType.studying, StatusType.eating,
      // Fila 4: Solo SOS (sin elementos heredados/duplicados)
      StatusType.sos,
    ];
  }

  /// Verifica si las Quick Actions actuales son las por defecto
  static Future<bool> areDefaultQuickActions() async {
    final current = await getUserQuickActions();
    if (current.length != _defaultQuickActions.length) return false;
    
    for (int i = 0; i < current.length; i++) {
      if (current[i] != _defaultQuickActions[i]) return false;
    }
    return true;
  }

  /// Obtiene las Quick Actions por defecto
  static List<StatusType> getDefaultQuickActions() {
    return List.from(_defaultQuickActions);
  }
}