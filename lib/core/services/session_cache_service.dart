// lib/core/services/session_cache_service.dart

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de caché de sesión para sobrevivir a destrucción de MainActivity
/// 
/// PROBLEMA: Android puede destruir la Activity cuando la app se minimiza
/// SOLUCIÓN: Guardar sesión en SharedPreferences para restaurar instantáneamente
/// 
/// FASE 2B - Point 20: Mitigación de limitación Android
class SessionCacheService {
  // Keys para SharedPreferences
  static const _USER_ID_KEY = 'zync_cached_user_id';
  static const _USER_EMAIL_KEY = 'zync_cached_user_email';
  static const _CIRCLE_ID_KEY = 'zync_cached_circle_id';
  static const _LAST_SAVE_KEY = 'zync_cached_last_save';
  
  // Cache de la instancia de SharedPreferences para acceso rápido
  static SharedPreferences? _prefsInstance;
  
  // Cache en memoria para acceso instantáneo (sin I/O)
  static Map<String, String>? _memoryCache;
  
  // Completer para sincronizar init() con restoreSession()
  static Completer<void>? _initCompleter;
  
  /// Inicializar el servicio (llamar al inicio de la app)
  /// 
  /// OPTIMIZADO: Carga rápida y no bloquea si ya está en progreso
  static Future<void> init() async {
    // Si ya está inicializado, retornar inmediatamente
    if (_memoryCache != null && _prefsInstance != null) {
      print('✅ [SessionCache] Ya inicializado (skip)');
      return;
    }
    
    // Si hay una inicialización en progreso, esperar (pero esto debería ser raro)
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      print('⚠️ [SessionCache] Init en progreso, esperando...');
      return _initCompleter!.future;
    }
    
    // Crear completer para sincronización
    _initCompleter = Completer<void>();
    
    try {
      final startTime = DateTime.now();
      
      // Obtener SharedPreferences
      _prefsInstance = await SharedPreferences.getInstance();
      
      // PRE-CARGAR datos en memoria para acceso instantáneo (0ms)
      final userId = _prefsInstance!.getString(_USER_ID_KEY) ?? '';
      final email = _prefsInstance!.getString(_USER_EMAIL_KEY) ?? '';
      final circleId = _prefsInstance!.getString(_CIRCLE_ID_KEY) ?? '';
      final lastSave = _prefsInstance!.getString(_LAST_SAVE_KEY) ?? '';
      
      _memoryCache = {
        'userId': userId,
        'email': email,
        'circleId': circleId,
        'lastSave': lastSave,
      };
      
      final duration = DateTime.now().difference(startTime);
      print('✅ [SessionCache] Servicio inicializado en ${duration.inMilliseconds}ms');
      print('💾 [SessionCache] Cache en memoria: ${userId.isNotEmpty ? "SÍ ($userId)" : "NO"}');
      
      // Completar inicialización
      _initCompleter!.complete();
    } catch (e) {
      print('❌ [SessionCache] Error inicializando: $e');
      // Inicializar cache vacío para no bloquear
      _memoryCache = {
        'userId': '',
        'email': '',
        'circleId': '',
        'lastSave': '',
      };
      _initCompleter!.completeError(e);
    }
  }

  /// Guardar sesión del usuario al pausar la app
  /// 
  /// Se llama automáticamente desde main.dart cuando la app entra en background
  static Future<void> saveSession({
    required String userId,
    required String email,
    String? circleId,
  }) async {
    try {
      final saveStart = DateTime.now();
      
      // Usar instancia cacheada o crear nueva (fallback)
      final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
      
      final lastSave = DateTime.now().toIso8601String();
      
      await prefs.setString(_USER_ID_KEY, userId);
      await prefs.setString(_USER_EMAIL_KEY, email);
      
      if (circleId != null && circleId.isNotEmpty) {
        await prefs.setString(_CIRCLE_ID_KEY, circleId);
      } else {
        await prefs.remove(_CIRCLE_ID_KEY);
      }
      
      await prefs.setString(_LAST_SAVE_KEY, lastSave);
      
      // Actualizar cache en memoria simultáneamente
      _memoryCache = {
        'userId': userId,
        'email': email,
        'circleId': circleId ?? '',
        'lastSave': lastSave,
      };
      
      final duration = DateTime.now().difference(saveStart);
      print('💾 [SessionCache] Sesión guardada en ${duration.inMilliseconds}ms: $userId');
      
    } catch (e) {
      print('❌ [SessionCache] Error guardando sesión: $e');
      // No lanzar excepción - es un fallback, no crítico
    }
  }

  /// Restaurar sesión desde memoria (síncrono, 0ms)
  /// 
  /// Retorna null si no hay sesión en memoria, requiere llamar a restoreSessionAsync()
  static Map<String, String>? restoreSessionSync() {
    if (_memoryCache != null && _memoryCache!.isNotEmpty) {
      final userId = _memoryCache!['userId'];
      if (userId != null && userId.isNotEmpty) {
        print('⚡ [SessionCache] Sesión desde memoria (0ms): $userId');
        return Map<String, String>.from(_memoryCache!);
      }
    }
    return null;
  }

  /// Restaurar sesión del usuario al maximizar la app
  /// 
  /// OPTIMIZADO: Lectura directa desde memoria (0ms) o SharedPreferences
  /// NO espera a que init() termine - usa cache en memoria primero
  static Future<Map<String, String>?> restoreSession() async {
    try {
      final restoreStart = DateTime.now();
      
      // 1. Intentar desde cache en memoria (instantáneo, 0ms)
      if (_memoryCache != null && _memoryCache!.isNotEmpty) {
        final userId = _memoryCache!['userId'];
        
        if (userId == null || userId.isEmpty) {
          print('💾 [SessionCache] No hay sesión en cache');
          return null;
        }
        
        final duration = DateTime.now().difference(restoreStart);
        print('⚡ [SessionCache] Sesión desde memoria (${duration.inMilliseconds}ms): $userId');
        return Map<String, String>.from(_memoryCache!);
      }
      
      // 2. Si no hay cache en memoria, leer directamente de SharedPreferences
      // SIN esperar a init() - esto es más rápido que esperar
      print('⚠️ [SessionCache] Leyendo directamente de SharedPreferences');
      final prefsStart = DateTime.now();
      final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
      final prefsDuration = DateTime.now().difference(prefsStart);
      print('⏱️ [SessionCache] SharedPreferences.getInstance(): ${prefsDuration.inMilliseconds}ms');
      
      // Pre-cargar en memoria para próximas llamadas
      _prefsInstance ??= prefs;
      
      final userId = prefs.getString(_USER_ID_KEY);

      if (userId == null || userId.isEmpty) {
        print('💾 [SessionCache] No hay sesión guardada');
        return null;
      }
      
      // Guardar en memoria para próximas llamadas
      _memoryCache = {
        'userId': userId,
        'email': prefs.getString(_USER_EMAIL_KEY) ?? '',
        'circleId': prefs.getString(_CIRCLE_ID_KEY) ?? '',
        'lastSave': prefs.getString(_LAST_SAVE_KEY) ?? '',
      };
      
      print('✅ [SessionCache] Sesión cargada y cacheada: $userId');

      final lastSave = prefs.getString(_LAST_SAVE_KEY);
      final email = prefs.getString(_USER_EMAIL_KEY) ?? '';
      final circleId = prefs.getString(_CIRCLE_ID_KEY) ?? '';

      print('💾 [SessionCache] Sesión restaurada: $userId (guardada: $lastSave)');

      return {
        'userId': userId,
        'email': email,
        'circleId': circleId,
        'lastSave': lastSave ?? '',
      };
      
    } catch (e) {
      print('❌ [SessionCache] Error restaurando sesión: $e');
      return null;
    }
  }

  /// Limpiar sesión al cerrar sesión del usuario
  /// 
  /// Se llama desde AuthWrapper cuando el usuario hace logout
  static Future<void> clearSession() async {
    try {
      final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
      
      await prefs.remove(_USER_ID_KEY);
      await prefs.remove(_USER_EMAIL_KEY);
      await prefs.remove(_CIRCLE_ID_KEY);
      await prefs.remove(_LAST_SAVE_KEY);
      
      // Limpiar cache en memoria
      _memoryCache = {
        'userId': '',
        'email': '',
        'circleId': '',
        'lastSave': '',
      };
      
      print('🗑️ [SessionCache] Sesión limpiada');
      
    } catch (e) {
      print('❌ [SessionCache] Error limpiando sesión: $e');
    }
  }

  /// Verificar si hay una sesión guardada (sin cargarla)
  /// 
  /// Útil para decisiones rápidas sin deserializar datos
  static Future<bool> hasSession() async {
    try {
      final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
      final userId = prefs.getString(_USER_ID_KEY);
      return userId != null && userId.isNotEmpty;
    } catch (e) {
      print('❌ [SessionCache] Error verificando sesión: $e');
      return false;
    }
  }

  /// Obtener timestamp de última sesión guardada
  /// 
  /// Útil para debugging y métricas de performance
  static Future<DateTime?> getLastSaveTime() async {
    try {
      final prefs = _prefsInstance ?? await SharedPreferences.getInstance();
      final lastSaveStr = prefs.getString(_LAST_SAVE_KEY);
      
      if (lastSaveStr == null) return null;
      
      return DateTime.parse(lastSaveStr);
    } catch (e) {
      print('❌ [SessionCache] Error obteniendo timestamp: $e');
      return null;
    }
  }
}
