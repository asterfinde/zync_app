import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/quick_actions_preferences_service.dart';
import '../core/models/user_status.dart';
import '../services/circle_service.dart';
import 'dart:developer';

/// Servicio para gestionar Quick Actions NATIVAMENTE (sin plugin Flutter)
///
/// Funcionalidad condicional según membresía en círculo:
/// - SIN círculo: Solo mostrar "Cerrar Sesión"
/// - CON círculo: Mostrar 4 estados configurados + actualización Firebase sin abrir app
class QuickActionsService {
  static const _platform = MethodChannel('zync/native_shortcuts');
  static bool _isInitialized = false;

  /// Inicializa Quick Actions usando implementación nativa
  /// IMPORTANTE: NO usa el plugin quick_actions de Flutter
  static Future<void> initialize() async {
    if (_isInitialized) {
      log('[QuickActionsService] ⚠️ Ya inicializado, saltando...');
      return;
    }

    try {
      // 1. Configuración inicial (puede ser null si no hay usuario aún)
      await updateQuickActionsBasedOnCircle();

      // 2. Escuchar cambios de autenticación para actualizar shortcuts
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        log('[QuickActionsService] 🔄 Auth state changed: ${user?.uid}');
        await updateQuickActionsBasedOnCircle();
      });

      _isInitialized = true;
      log('[QuickActionsService] ✅ Inicializado - Shortcuts nativos configurados y escuchando Auth');
    } catch (e) {
      log('[QuickActionsService] ❌ Error inicializando: $e');
    }
  }

  /// Actualiza Quick Actions según membresía en círculo
  /// - NO círculo: Solo "Cerrar Sesión"
  /// - SI círculo: 4 estados configurados
  static Future<void> updateQuickActionsBasedOnCircle() async {
    try {
      final circleService = CircleService();
      final userCircle = await circleService.getUserCircle();

      if (userCircle == null) {
        // Usuario NO tiene círculo -> Solo Cerrar Sesión
        log('[QuickActionsService] ⛔ Usuario sin círculo, solo mostrando Cerrar Sesión');
        await _setupLogoutOnlyShortcuts();
      } else {
        // Usuario tiene círculo -> Mostrar 4 estados
        log('[QuickActionsService] ✅ Usuario en círculo ${userCircle.name}, configurando estados');
        await _setupUserStatusShortcuts();
      }
    } catch (e) {
      log('[QuickActionsService] ❌ Error actualizando Quick Actions: $e');
    }
  }

  /// Configura Quick Actions solo con Cerrar Sesión
  static Future<void> _setupLogoutOnlyShortcuts() async {
    try {
      await _platform.invokeMethod('updateShortcuts', {
        'hasCircle': false,
        'shortcuts': [],
      });
      log('[QuickActionsService] 🚪 Shortcuts nativos: Solo Cerrar Sesión');
    } catch (e) {
      log('[QuickActionsService] ❌ Error configurando logout: $e');
    }
  }

  /// Configura Quick Actions con los 4 estados del usuario
  static Future<void> _setupUserStatusShortcuts() async {
    try {
      // Obtener las 4 Quick Actions configuradas por el usuario
      final userQuickActions = await QuickActionsPreferencesService.getUserQuickActions();

      // Convertir a formato nativo
      final shortcuts = userQuickActions.map((status) {
        final statusName = status.toString().split('.').last;
        return {
          'type': statusName, // 'fine', 'busy', etc.
          'emoji': status.emoji,
          'label': status.description,
        };
      }).toList();

      // Llamar a MethodChannel nativo
      await _platform.invokeMethod('updateShortcuts', {
        'hasCircle': true,
        'shortcuts': shortcuts,
      });

      log('[QuickActionsService] ✅ ${shortcuts.length} Shortcuts nativos configurados: ${userQuickActions.map((s) => s.emoji).join(' ')}');
    } catch (e) {
      log('[QuickActionsService] ❌ Error configurando estados: $e');
      // Fallback a estados por defecto
      await _setupDefaultStatusShortcuts();
    }
  }

  /// Configuración de fallback con estados por defecto
  static Future<void> _setupDefaultStatusShortcuts() async {
    log('[QuickActionsService] ⚙️ Usando estados por defecto (fallback)');

    try {
      await _platform.invokeMethod('updateShortcuts', {
        'hasCircle': true,
        'shortcuts': [
          {'type': 'fine', 'emoji': '🙂', 'label': 'Todo bien'},
          {'type': 'busy', 'emoji': '🔴', 'label': 'Ocupado'},
          {'type': 'sos', 'emoji': '🆘', 'label': 'SOS'},
          {'type': 'meeting', 'emoji': '💼', 'label': 'En reunión'},
        ],
      });
    } catch (e) {
      log('[QuickActionsService] ❌ Error en fallback: $e');
    }
  }

  /// Habilita o deshabilita Quick Actions
  /// Usado cuando el usuario entra/sale de un círculo
  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await updateQuickActionsBasedOnCircle();
    } else {
      try {
        await _platform.invokeMethod('clearShortcuts');
        log('[QuickActionsService] 🧹 Shortcuts nativos limpiados');
      } catch (e) {
        log('[QuickActionsService] ❌ Error limpiando shortcuts: $e');
      }
    }
  }

  /// Actualiza Quick Actions cuando el usuario cambia su configuración
  static Future<void> refreshUserShortcuts() async {
    log('[QuickActionsService] 🔄 Refrescando Quick Actions del usuario');
    await _setupUserStatusShortcuts();
  }

  /// Actualiza los Quick Actions cuando el usuario cambia su configuración
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
        // Actualizar los Quick Actions del sistema
        await _setupUserStatusShortcuts();
        log('[QuickActionsService] ✅ Quick Actions actualizadas por el usuario');
      } else {
        log('[QuickActionsService] ❌ Error guardando preferencias');
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
