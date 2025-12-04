import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/user_status.dart';
import 'emoji_service.dart';
import 'dart:convert';
import 'dart:developer';

/// Servicio para manejar las preferencias de Quick Actions del usuario
/// Permite seleccionar y guardar hasta 4 StatusTypes favoritos para Quick Actions
/// REFACTORED: Ahora usa EmojiService para cargar desde Firebase
class QuickActionsPreferencesService {
  static const String _prefsKey = 'quick_actions_preferences';

  /// IDs de Quick Actions por defecto (las 4 más comunes)
  static const List<String> _defaultQuickActionIds = [
    'available', // 🟢 Disponible
    'busy', // 🔴 Ocupado
    'away', // 🟡 Ausente
    'sos', // 🆘 SOS
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

        // Obtener circleId del usuario actual
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Usuario no autenticado');

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        final circleId = userDoc.data()?['circleId'] as String?;
        if (circleId == null) throw Exception('Usuario sin círculo');

        // Obtener todos los emojis (predefinidos + personalizados)
        final allEmojis = await EmojiService.getAllEmojisForCircle(circleId);

        // Convertir IDs guardados a StatusType
        for (String statusId in savedList) {
          try {
            final statusType = allEmojis.firstWhere(
              (s) => s.id == statusId,
            );
            quickActions.add(statusType);
          } catch (e) {
            log('[QuickActionsPrefs] Status no encontrado: $statusId');
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
      return await _getDefaultQuickActions();
    } catch (e) {
      log('[QuickActionsPrefs] ❌ Error cargando preferencias: $e');
      return await _getDefaultQuickActions();
    }
  }

  /// Obtiene StatusTypes por defecto desde Firebase
  static Future<List<StatusType>> _getDefaultQuickActions() async {
    try {
      final predefinedEmojis = await EmojiService.getPredefinedEmojis();
      final defaults = <StatusType>[];

      for (String id in _defaultQuickActionIds) {
        try {
          final status = predefinedEmojis.firstWhere((s) => s.id == id);
          defaults.add(status);
        } catch (e) {
          log('[QuickActionsPrefs] ⚠️ Default ID no encontrado: $id');
        }
      }

      // Fallback si Firebase no tiene los defaults
      if (defaults.length == 4) {
        return defaults;
      } else {
        return StatusType.fallbackPredefined.take(4).toList();
      }
    } catch (e) {
      log('[QuickActionsPrefs] ❌ Error cargando defaults desde Firebase: $e');
      return StatusType.fallbackPredefined.take(4).toList();
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

      // Convertir StatusTypes a IDs para guardar
      final List<String> statusIds = quickActions.map((status) => status.id).toList();

      final savedData = json.encode(statusIds);
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
      final defaults = await _getDefaultQuickActions();
      final success = await saveUserQuickActions(defaults);
      log('[QuickActionsPrefs] 🔄 Quick Actions reseteadas a defaults');
      return success;
    } catch (e) {
      log('[QuickActionsPrefs] ❌ Error reseteando: $e');
      return false;
    }
  }

  /// Obtiene todos los StatusTypes disponibles para Quick Actions
  /// Retorna predefinidos + personalizados del círculo del usuario
  static Future<List<StatusType>> getAvailableStatusTypes() async {
    try {
      // Obtener circleId del usuario actual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId == null) throw Exception('Usuario sin círculo');

      // Obtener todos los emojis (predefinidos + personalizados)
      final allEmojis = await EmojiService.getAllEmojisForCircle(circleId);
      log('[QuickActionsPrefs] ✅ ${allEmojis.length} emojis disponibles para Quick Actions (predefinidos + personalizados)');
      return allEmojis;
    } catch (e) {
      log('[QuickActionsPrefs] ❌ Error cargando emojis: $e');
      return StatusType.fallbackPredefined;
    }
  }

  /// Verifica si las Quick Actions actuales son las por defecto
  static Future<bool> areDefaultQuickActions() async {
    final current = await getUserQuickActions();
    final defaults = await _getDefaultQuickActions();

    if (current.length != defaults.length) return false;

    for (int i = 0; i < current.length; i++) {
      if (current[i].id != defaults[i].id) return false;
    }
    return true;
  }

  /// Obtiene las Quick Actions por defecto
  static Future<List<StatusType>> getDefaultQuickActions() async {
    return await _getDefaultQuickActions();
  }
}
