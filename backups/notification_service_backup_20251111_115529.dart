import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  /// Muestra notificación persistente para cambiar estado - Point 15: ESTÁTICA
  static Future<void> showQuickActionNotification({StatusType? currentStatus}) async {
    await _ensureInitialized();

    // Point 15: Texto estático - no hacer eco con cambios
    const statusText = 'Tap to change your status';

    const androidDetails = AndroidNotificationDetails(
      'zync_quick_actions',
      'Quick Status Access',
      channelDescription: 'Quick access to status changes',
      importance: Importance.high, // CAMBIO: HIGH para que sea visible
      priority: Priority.high,     // CAMBIO: HIGH para que aparezca arriba
      silent: false,              // CAMBIO: false para que sea visible
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      visibility: NotificationVisibility.public, // NUEVO: Forzar visibilidad pública
      // Removemos actions para evitar confusión - modal manejará todo
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

    try {
      await _notifications.show(
        9999, // ID fijo para la notificación persistente
        'Zync Status',
        statusText,
        notificationDetails,
        payload: 'quick_action_tap',
      );

      log('[NotificationService] 🔕 Point 15: Notificación estática mostrada (no eco): $statusText');
      log('[NotificationService] 🔔 Notification ID: 9999, Ongoing: true, Importance: HIGH');
    } catch (e) {
      // Point 21: Fallback silencioso - usuario puede haber denegado permisos
      log('[NotificationService] ⚠️ No se pudo mostrar notificación (permisos denegados?): $e');
      log('[NotificationService] 🔕 App continuará funcionando sin notificaciones persistentes');
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
    await _notifications.cancel(9999);
    log('[NotificationService] 🚫 Persistent notification cancelled (ID: 9999)');
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

  /// Solicita permisos de notificación (principalmente para iOS)
  /// Point 21: En Android no hace nada - permisos en AndroidManifest.xml
  static Future<bool> requestPermissions() async {
    await _ensureInitialized();
    
    // Point 21: En Android retornamos true directamente (permisos en manifest)
    // Solo procesamos permisos en iOS si es necesario
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
    
    return true; // Android: permisos automáticos del manifest
  }
}