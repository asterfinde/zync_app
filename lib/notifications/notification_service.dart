import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart'; // Point 21 FASE 5: Para MethodChannel
import '../features/circle/domain_old/entities/user_status.dart';
import 'dart:developer';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;

  /// Inicializa el servicio de notificaciones
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Configuración para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS (solo solicitar permisos en iOS, no en Android)
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: false, // Point 21: Silencioso
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Point 21: NO solicitar permisos - se declaran en AndroidManifest.xml
    // El permiso POST_NOTIFICATIONS se maneja automáticamente en Android
    
    // Crear canal de notificaciones (silencioso)
    await _createNotificationChannel();

    _isInitialized = true;
    log('[NotificationService] ✅ Initialized successfully (silent mode)');
  }

  /// Muestra una notificación silenciosa con acción de estado
  static Future<void> showSilentNotification(StatusType status) async {
    await _ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      'zync_status_channel',
      'Status Updates',
      channelDescription: 'Silent status update notifications',
      importance: Importance.low,
      priority: Priority.low,
      silent: true,
      showWhen: false,
      ongoing: false,
      autoCancel: true,
      actions: [
        AndroidNotificationAction(
          'quick_status',
          'Quick Status',
          showsUserInterface: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
      interruptionLevel: InterruptionLevel.passive,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      status.hashCode,
      'Zync Status Updated',
      '${status.emoji} ${status.description}',
      notificationDetails,
      payload: 'status_update:${status.name}',
    );

    log('[NotificationService] Silent notification shown for ${status.description}');
  }

  /// Point 21 FASE 5: Muestra notificación persistente NATIVA
  /// Usa el método nativo de MainActivity que apunta a StatusModalActivity
  static Future<void> showQuickActionNotification({StatusType? currentStatus}) async {
    await _ensureInitialized();

    try {
      // FASE 5 FIX: Usar el canal nativo existente que ya apunta a StatusModalActivity
      const platform = MethodChannel('mini_emoji/notification');
      
      log('[NotificationService] 🎯 [FASE 5] Solicitando notificación NATIVA a Android...');
      log('[NotificationService] 📡 Usando canal: mini_emoji/notification → showNotification');
      
      final result = await platform.invokeMethod('showNotification');
      
      log('[NotificationService] ✅ [FASE 5] Notificación nativa creada: $result');
      log('[NotificationService] 🎯 [FASE 5] Tap abrirá StatusModalActivity (modal transparente)');
      
    } catch (e) {
      log('[NotificationService] ❌ [FASE 5] Error creando notificación nativa: $e');
      log('[NotificationService] � [FASE 5] Asegúrate de que el método nativo esté disponible');
      rethrow;
    }
  }

  /// Cancela todas las notificaciones
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
    log('[NotificationService] All notifications cancelled');
  }

  /// Cancela la notificación de quick actions
  static Future<void> cancelQuickActionNotification() async {
    await _ensureInitialized();
    
    try {
      // Cancelar notificación nativa de Android
      const platform = MethodChannel('mini_emoji/notification');
      await platform.invokeMethod('cancelNotification');
      log('[NotificationService] ✅ Notificación nativa cancelada desde Android');
    } catch (e) {
      log('[NotificationService] ⚠️ Error cancelando notificación nativa: $e');
    }
    
    // Cancelar también cualquier notificación Flutter local
    await _notifications.cancel(9999);
    log('[NotificationService] Quick action notification cancelled');
  }
  
  /// Point 1.1: Cancela TODAS las notificaciones de forma agresiva (incluye KeepAliveService)
  static Future<void> cancelAllNotificationsAggressive() async {
    await _ensureInitialized();
    
    log('[NotificationService] 🔴🔴🔴 CANCELACIÓN AGRESIVA: Eliminando TODAS las notificaciones...');
    
    try {
      // 1. Cancelar todas las notificaciones Flutter locales
      await _notifications.cancelAll();
      log('[NotificationService] ✅ Notificaciones Flutter canceladas');
    } catch (e) {
      log('[NotificationService] ⚠️ Error cancelando notificaciones Flutter: $e');
    }
    
    try {
      // 2. Llamar al método nativo que cancela TODAS (MainActivity + KeepAliveService)
      const platform = MethodChannel('mini_emoji/notification');
      await platform.invokeMethod('cancelAllNotifications');
      log('[NotificationService] ✅ Método nativo cancelAllNotifications() ejecutado');
      log('[NotificationService] ✅ TODAS las notificaciones eliminadas (incluye MainActivity y KeepAliveService)');
    } catch (e) {
      log('[NotificationService] ⚠️ Error llamando método nativo cancelAllNotifications: $e');
      // Intentar método antiguo como fallback
      try {
        const platform = MethodChannel('mini_emoji/notification');
        await platform.invokeMethod('cancelNotification');
        log('[NotificationService] ⚠️ Fallback: Usó método antiguo cancelNotification');
      } catch (e2) {
        log('[NotificationService] ❌ Error en fallback: $e2');
      }
    }
  }
  
  /// Point 21 FASE 5: Abre la configuración de notificaciones de Android
  static Future<void> openNotificationSettings() async {
    try {
      const platform = MethodChannel('mini_emoji/notification');
      
      log('[NotificationService] Abriendo Settings de Android...');
      
      final result = await platform.invokeMethod('openNotificationSettings');
      
      if (result == true) {
        log('[NotificationService] Settings abierto exitosamente');
      } else {
        log('[NotificationService] No se pudo abrir Settings');
      }
    } catch (e) {
      log('[NotificationService] Error abriendo Settings: $e');
    }
  }

  /// Handler para cuando se toca una notificación
  static void _onNotificationTapped(NotificationResponse response) {
    log('[NotificationService] Notification tapped: ${response.payload}');
    
    // Si es la notificación persistente (ID 9999), abrir modal
    if (response.id == 9999) {
      _handleQuickActionTap();
      return;
    }
    
    if (response.actionId != null) {
      _handleNotificationAction(response.actionId!);
    } else if (response.payload != null) {
      _handleNotificationPayload(response.payload!);
    }
  }

  /// Callback para manejar tap en notificación persistente
  static void Function()? _onQuickActionTap;
  
  /// Registra callback para el tap en notificación persistente
  static void setQuickActionTapHandler(void Function() onTap) {
    _onQuickActionTap = onTap;
  }

  /// Maneja el tap en la notificación persistente
  static void _handleQuickActionTap() {
    log('[NotificationService] Quick action notification tapped');
    _onQuickActionTap?.call();
  }

  /// Maneja las acciones de las notificaciones
  static void _handleNotificationAction(String actionId) {
    log('[NotificationService] Handling action: $actionId');
    
    // Las acciones se manejarán a través del NotificationActions
    // Este método puede expandirse para manejar diferentes tipos de acciones
  }

  /// Maneja el payload de las notificaciones
  static void _handleNotificationPayload(String payload) {
    log('[NotificationService] Handling payload: $payload');
    
    if (payload.startsWith('status_update:')) {
      final statusName = payload.split(':')[1];
      log('[NotificationService] Status update payload: $statusName');
    }
  }

  // Point 21: Método eliminado - ya no solicitamos permisos manualmente
  // Los permisos se declaran en AndroidManifest.xml y se otorgan automáticamente

  /// Crea el canal de notificaciones para Android (completamente silencioso)
  static Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'zync_quick_actions',
      'Quick Status Access',
      description: 'Quick access to status changes',
      importance: Importance.low, // Point 21: LOW para no molestar
      enableVibration: false,
      playSound: false,
      showBadge: false, // Point 21: Sin badge
    );

    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      try {
        await androidImplementation.createNotificationChannel(channel);
        log('[NotificationService] 🔔 Silent notification channel created: ${channel.id}');
      } catch (e) {
        // Point 21: Fallback silencioso si no hay permisos
        log('[NotificationService] ⚠️ Could not create channel (permissions may be denied): $e');
      }
    }
  }

  /// Asegura que el servicio esté inicializado
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Verifica si tenemos permisos de notificación
  /// Android 13+ (API 33+) requiere permisos explícitos en tiempo de ejecución
  static Future<bool> hasPermission() async {
    await _ensureInitialized();
    
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final result = await androidImplementation.areNotificationsEnabled();
      log('[NotificationService] 🔍 Permisos de notificación: ${result ?? false}');
      return result ?? false;
    }
    
    // iOS
    final iosImplementation = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImplementation != null) {
      final result = await iosImplementation.requestPermissions(
        alert: false,
        badge: false,
        sound: false,
      );
      return result ?? true;
    }
    
    return true; // Fallback
  }

  /// Solicita permisos de notificación
  /// Point 21 FASE 1 FIX: Android 13+ (API 33+) requiere permisos explícitos
  static Future<bool> requestPermissions() async {
    await _ensureInitialized();
    
    // Android 13+ (API 33+): Solicitar permisos explícitamente
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      log('[NotificationService] 📱 Android 13+ detectado - solicitando permisos...');
      
      // Verificar primero si ya tenemos permisos
      final hasPermissions = await androidImplementation.areNotificationsEnabled();
      
      if (hasPermissions == true) {
        log('[NotificationService] ✅ Ya tenemos permisos de notificación');
        return true;
      }
      
      // Solicitar permisos
      log('[NotificationService] ⚠️ No hay permisos - solicitando al usuario...');
      final result = await androidImplementation.requestNotificationsPermission();
      log('[NotificationService] 🔔 Resultado de solicitud de permisos: $result');
      return result ?? false;
    }
    
    // iOS
    final iosImplementation = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImplementation != null) {
      final result = await iosImplementation.requestPermissions(
        alert: false, // Point 21: Silencioso
        badge: false,
        sound: false,
      );
      return result ?? true;
    }
    
    return true; // Fallback para Android <13
  }
}