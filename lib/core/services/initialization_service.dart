import 'package:zync_app/core/di/injection_container.dart' as di;
import 'package:zync_app/core/widgets/status_widget.dart';
import 'package:zync_app/widgets/widget_service.dart';
import 'package:zync_app/quick_actions/quick_actions_service.dart';
import 'package:zync_app/notifications/notification_service.dart';
import 'package:zync_app/core/services/silent_functionality_coordinator.dart';
import 'package:zync_app/core/services/app_badge_service.dart';

/// Servicio centralizado de inicialización
/// Se ejecuta en BACKGROUND para no bloquear el splash screen
class InitializationService {
  static bool _isInitialized = false;
  
  /// Inicializa todos los servicios de la app en background
  /// OPTIMIZACIÓN: Se ejecuta DESPUÉS de mostrar el splash screen
  static Future<void> initializeAllServices() async {
    if (_isInitialized) {
      print('⚡ [InitService] Servicios ya inicializados, saltando...');
      return;
    }
    
    try {
      print('🚀 [InitService] INICIO de inicialización de servicios');
      final startTime = DateTime.now();
      
      // 1. Dependency Injection
      print('  📦 [InitService] Inicializando DI...');
      await di.init();
      
      // 2. Status Widget Service
      print('  🎨 [InitService] Inicializando Status Widget...');
      await StatusWidgetService.initialize();
      
      // 3. Widget Service (home widgets)
      print('  📱 [InitService] Inicializando Widget Service...');
      await WidgetService.initialize();
      
      // 4. Quick Actions Service
      print('  ⚡ [InitService] Inicializando Quick Actions...');
      await QuickActionsService.initialize();
      
      // 5. Notification Service
      print('  🔔 [InitService] Inicializando Notifications...');
      await NotificationService.initialize();
      
      // 6. App Badge Service
      print('  🔴 [InitService] Inicializando App Badge...');
      await AppBadgeService.initialize();
      
      // 7. Silent Functionality Coordinator
      print('  🤫 [InitService] Inicializando Silent Coordinator...');
      await SilentFunctionalityCoordinator.initializeServices();
      
      _isInitialized = true;
      
      final duration = DateTime.now().difference(startTime);
      print('✅ [InitService] Todos los servicios inicializados en ${duration.inMilliseconds}ms');
      
    } catch (e, stackTrace) {
      print('❌ [InitService] Error durante inicialización: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Verifica si los servicios están inicializados
  static bool get isInitialized => _isInitialized;
}
