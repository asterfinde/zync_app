// Se mantiene por si acaso
import 'package:zync_app/core/widgets/status_widget.dart';
import 'package:zync_app/widgets/widget_service.dart';
import 'package:zync_app/quick_actions/quick_actions_service.dart';
import 'package:zync_app/notifications/notification_service.dart';
import 'package:zync_app/core/services/silent_functionality_coordinator.dart';
import 'package:zync_app/core/services/app_badge_service.dart';

/// Servicio centralizado de inicialización
/// Se ejecuta en BACKGROUND para no bloquear el splash screen
class InitializationService {
  static bool _areNonDIServicesInitialized = false; // <-- CAMBIAR NOMBRE VARIABLE
  
  // --- INICIO DE LA MODIFICACIÓN ---
  /// Inicializa los servicios que NO son de DI en background
  /// OPTIMIZACIÓN: Se ejecuta DESPUÉS de mostrar el splash screen y en un Isolate separado
  static Future<void> initializeNonDIServices() async { // <-- CAMBIAR NOMBRE FUNCIÓN
    if (_areNonDIServicesInitialized) { // <-- USAR NUEVA VARIABLE
      print('⚡ [InitService] Servicios (no DI) ya inicializados, saltando...');
      return;
    }
    
    try {
      print('🚀 [InitService - BG Isolate] INICIO de inicialización de servicios (no DI)');
      final startTime = DateTime.now();
      
      // --- DI YA NO SE INICIALIZA AQUÍ ---
      // print('  📦 [InitService] Inicializando DI...'); 
      // await di.init(); // <-- ELIMINADO

      // 1. Status Widget Service
      print('  🎨 [InitService - BG Isolate] Inicializando Status Widget...');
      await StatusWidgetService.initialize();
      
      // 2. Widget Service (home widgets)
      print('  📱 [InitService - BG Isolate] Inicializando Widget Service...');
      await WidgetService.initialize();
      
      // 3. Quick Actions Service
      print('  ⚡ [InitService - BG Isolate] Inicializando Quick Actions...');
      await QuickActionsService.initialize();
      
      // 4. Notification Service
      print('  🔔 [InitService - BG Isolate] Inicializando Notifications...');
      await NotificationService.initialize();
      
      // 5. App Badge Service
      print('  🔴 [InitService - BG Isolate] Inicializando App Badge...');
      await AppBadgeService.initialize();
      
      // 6. Silent Functionality Coordinator
      print('  🤫 [InitService - BG Isolate] Inicializando Silent Coordinator...');
      await SilentFunctionalityCoordinator.initializeServices();
      
      _areNonDIServicesInitialized = true; // <-- USAR NUEVA VARIABLE
      
      final duration = DateTime.now().difference(startTime);
      print('✅ [InitService - BG Isolate] Servicios (no DI) inicializados en ${duration.inMilliseconds}ms');
      
    } catch (e, stackTrace) {
      print('❌ [InitService - BG Isolate] Error durante inicialización (no DI): $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Verifica si los servicios (no DI) están inicializados
  static bool get areNonDIServicesInitialized => _areNonDIServicesInitialized; // <-- CAMBIAR NOMBRE GETTER
  // --- FIN DE LA MODIFICACIÓN ---

  // Mantener por compatibilidad con AuthWrapper
  static bool get isInitialized => _areNonDIServicesInitialized; 
}