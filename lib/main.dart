// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zync_app/firebase_options.dart';
import 'package:zync_app/features/auth/presentation/pages/auth_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/core/models/user_status.dart';
// import 'package:zync_app/core/di/injection_container.dart' as di; // 🔥 SIMPLIFICADO: Ya no se usa para Auth
import 'package:zync_app/core/cache/persistent_cache.dart'; // CACHE PERSISTENTE
import 'package:zync_app/core/utils/performance_tracker.dart'; // PERFORMANCE TRACKING
import 'package:zync_app/core/services/session_cache_service.dart'; // FASE 2B: Session Cache (fallback)
import 'package:zync_app/core/services/native_state_bridge.dart'; // FASE 3: Native State (primario) (fallback)
import 'package:zync_app/core/services/silent_functionality_coordinator.dart'; // Point 2: Silent Functionality
import 'package:zync_app/notifications/notification_service.dart'; // Point 2: Notification Service
import 'package:zync_app/core/services/status_service.dart'; // Para actualizar estado desde native
import 'package:zync_app/core/services/emoji_service.dart'; // Para cargar emojis desde Firebase
import 'package:zync_app/core/services/emoji_cache_service.dart'; // Para sincronizar emojis a cache nativo
// StatusType class
import 'package:zync_app/services/circle_service.dart'; // Para verificar membresía en círculo
import 'package:zync_app/core/splash/splash_screen.dart'; // Splash screen personalizado

import 'core/global_keys.dart';

// Point 21 FASE 5: NavigatorKey global para acceso al contexto desde servicios
// Necesario para StatusModalService cuando se abre desde notificaciones
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📊 PERFORMANCE: Medir inicialización
  PerformanceTracker.start('Firebase Init');

  // 🚀 CRITICAL PATH: Firebase + SessionCache ANTES de runApp()
  // Esto garantiza que el cache esté listo SIEMPRE
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  PerformanceTracker.end('Firebase Init');
  print('✅ [main] Firebase inicializado.');

  // 🎯 CRÍTICO: SessionCache ANTES de runApp() (patrón WhatsApp/Telegram)
  // NOTA: NativeState (Kotlin) se inicializa automáticamente en MainActivity.onCreate()
  // SessionCache aquí es fallback para compatibilidad
  PerformanceTracker.start('SessionCache Init');
  await SessionCacheService.init();
  PerformanceTracker.end('SessionCache Init');
  print('✅ [main] SessionCache inicializado (bloqueante).');

  // Point 2: Inicializar servicios de notificación ANTES de runApp()
  await SilentFunctionalityCoordinator.initializeServices();
  print('✅ [main] SilentFunctionalityCoordinator inicializado.');

  // 🔄 Sincronizar emojis de Firebase a cache nativo (para EmojiDialogActivity)
  await EmojiCacheService.syncEmojisToNativeCache();
  print('✅ [main] Emojis sincronizados a cache nativo.');

  // 🔍 Verificar si hay estado nativo disponible (solo Android)
  try {
    final nativeUserId = await NativeStateBridge.getUserId();
    if (nativeUserId != null && nativeUserId.isNotEmpty) {
      print('🚀 [main] Estado nativo encontrado: $nativeUserId');
    }
  } catch (e) {
    // Esperado en iOS o si falla la lectura
    print('ℹ️ [main] NativeState no disponible (Android only): $e');
  }

  // 👆 Handler para recibir actualizaciones de estado desde EmojiDialogActivity nativo
  const statusUpdateChannel = MethodChannel('com.datainfers.zync/status_update');
  statusUpdateChannel.setMethodCallHandler((call) async {
    if (call.method == 'updateStatus') {
      final statusTypeName = call.arguments['statusType'] as String?;
      print('👆 [NATIVE→FLUTTER] Recibido estado: $statusTypeName');

      if (statusTypeName != null) {
        await _updateStatusFromNative(statusTypeName);
      }
    }
  });
  print('✅ [main] Handler de estado nativo configurado.');

  // 💾 [HYBRID] Verificar si hay estado pendiente del cache (app estaba cerrada)
  try {
    const platform = MethodChannel('com.datainfers.zync/pending_status');
    final pendingStatus = await platform.invokeMethod('getPendingStatus');

    if (pendingStatus != null && pendingStatus is Map) {
      final statusTypeName = pendingStatus['statusType'] as String?;
      final timestamp = pendingStatus['timestamp'] as int?;

      if (statusTypeName != null && timestamp != null) {
        print('💾 [HYBRID] Estado pendiente encontrado: $statusTypeName (timestamp: $timestamp)');
        await _updateStatusFromNative(statusTypeName);

        // Limpiar cache después de actualizar
        await platform.invokeMethod('clearPendingStatus');
        print('✅ [HYBRID] Estado pendiente procesado y limpiado');
      }
    }
  } catch (e) {
    print('ℹ️ [HYBRID] No hay estado pendiente o error leyendo cache: $e');
  }

  // 🔥 SIMPLIFICADO: GetIt ya NO es necesario para Auth
  // AuthProvider ahora usa AuthService vía Riverpod
  // TODO: Eliminar GetIt completamente después de migrar Circle y otros features
  // PerformanceTracker.start('DI Init');
  // await di.init();
  // PerformanceTracker.end('DI Init');
  // print('✅ [main] GetIt (DI) inicializado antes de runApp.');
  print('✅ [main] Auth usa AuthService (sin GetIt).');

  // 🎯 RENDERIZAR UI (con cache ya disponible)
  runApp(const ProviderScope(child: MyApp()));
}

/// Helper para actualizar estado desde nativo (reutilizable)
Future<void> _updateStatusFromNative(String statusTypeName) async {
  try {
    // Obtener circleId del usuario para cargar emojis personalizados
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ [NATIVE→FLUTTER] Usuario no autenticado');
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final circleId = userDoc.data()?['circleId'] as String?;

    // Cargar TODOS los emojis (predefinidos + personalizados)
    List<StatusType> allEmojis;
    if (circleId != null) {
      allEmojis = await EmojiService.getAllEmojisForCircle(circleId);
      print('📦 [NATIVE→FLUTTER] Cargados ${allEmojis.length} emojis (predefinidos + personalizados)');
    } else {
      allEmojis = await EmojiService.getPredefinedEmojis();
      print('⚠️ [NATIVE→FLUTTER] Usuario sin círculo, solo predefinidos');
    }

    // Buscar el estado por ID
    final statusType = allEmojis.firstWhere(
      (e) => e.id == statusTypeName,
      orElse: () => allEmojis.first, // Default al primero si no encuentra
    );

    // Actualizar en Firebase usando StatusService
    final result = await StatusService.updateUserStatus(statusType);

    if (result.isSuccess) {
      print('✅ [NATIVE→FLUTTER] Estado actualizado en Firebase: ${statusType.description}');
    } else {
      print('❌ [NATIVE→FLUTTER] Error actualizando estado: ${result.errorMessage}');
    }
  } catch (e) {
    print('❌ [NATIVE→FLUTTER] Error procesando estado: $e');
  }

  // ⏳ LAZY: Inicializar PersistentCache DESPUÉS del primer frame
  // (GetIt ya fue inicializado antes de runApp)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    print('🔄 [main] Inicializando PersistentCache en background...');

    PerformanceTracker.start('Cache Init');
    await PersistentCache.init();
    PerformanceTracker.end('Cache Init');
    print('✅ [main] PersistentCache inicializado.');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // 📱 App minimizada - Guardar en múltiples capas
      print('📱 [App] Went to background - Guardando en NativeState + SessionCache...');
      PerformanceTracker.onAppPaused();

      final user = FirebaseAuth.instance.currentUser;
      print('🔍 [App] Usuario actual: ${user?.uid ?? "NULL"}');

      if (user != null) {
        // 🚀 Capa 1: NativeState (Kotlin/Room) - MÁS RÁPIDO (~5-10ms)
        // Nota: MainActivity.onPause() también guarda automáticamente
        NativeStateBridge.setUserId(
          userId: user.uid,
          email: user.email ?? '',
        ).then((_) {
          print('✅ [App] NativeState guardado');
        }).catchError((e) {
          print('ℹ️ [App] NativeState skip (esperado en iOS): $e');
        });

        // 🔄 Capa 2: SessionCache (Flutter SharedPreferences) - FALLBACK (~20-30ms)
        SessionCacheService.saveSession(
          userId: user.uid,
          email: user.email ?? '',
        ).then((_) {
          print('✅ [App] SessionCache guardado');
        }).catchError((e) {
          print('❌ [App] Error guardando SessionCache: $e');
        });
      } else {
        print('⚠️ [App] No hay usuario autenticado, no se guarda sesión');
      }
    } else if (state == AppLifecycleState.resumed) {
      // 📱 App maximizada - MEDIR RENDIMIENTO
      print('📱 [App] Resumed from background - Midiendo performance...');
      PerformanceTracker.start('App Maximization');
      PerformanceTracker.onAppResumed();

      // Point 2: Verificar permisos al regresar (usuario pudo haberlos activado en Settings)
      _checkPermissionsOnResume();

      // Esperar a que UI esté lista
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PerformanceTracker.end('App Maximization');

        // Mostrar reporte después de 1 segundo
        Future.delayed(const Duration(seconds: 1), () {
          final report = PerformanceTracker.getReport();
          debugPrint(report);
        });
      });
    }
  }

  // Point 2: Verificar permisos al regresar del background
  // Detecta si el usuario activó permisos en Settings
  Future<void> _checkPermissionsOnResume() async {
    // Solo verificar si hay un usuario autenticado
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[App Resume] No hay usuario autenticado - skip verificación permisos');
      return;
    }

    print('[App Resume] 🔍 Verificando permisos de notificación...');

    try {
      // CRÍTICO: Verificar PRIMERO si el usuario pertenece a un círculo
      print('[App Resume] Verificando pertenencia a círculo...');
      final circleService = CircleService();
      final userCircle = await circleService.getUserCircle();

      if (userCircle == null) {
        print('[App Resume] ⚠️ Usuario NO pertenece a círculo - NO mostrar notificaciones');
        return;
      }

      print('[App Resume] ✅ Usuario pertenece al círculo: ${userCircle.name}');

      final hasPermission = await NotificationService.hasPermission();

      if (hasPermission) {
        print('[App Resume] ✅ Permisos CONCEDIDOS - Activando notificación persistente...');
        await NotificationService.showQuickActionNotification();
        print('[App Resume] ✅ Notificación persistente activada');
      } else {
        print('[App Resume] ⚠️ Permisos DENEGADOS - notificación no disponible');
      }
    } catch (e) {
      print('[App Resume] ❌ Error verificando permisos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.tealAccent,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Zync App',
      theme: baseTheme,
      navigatorKey: navigatorKey, // Point 21 FASE 5: Para acceso desde StatusModalService
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      // Splash screen personalizado con logo ZYNC animado
      home: OptimizedSplashScreen(
        onInitialize: () async {
          // Esta función se ejecuta en background mientras se muestra el splash
          // No hacer nada aquí porque ya se inicializó todo en main()
          await Future.delayed(const Duration(milliseconds: 100));
        },
        child: const AuthWrapper(),
      ),
    );
  }
}


/////////////////////////////////////////////

// // lib/main.dart

// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:zync_app/firebase_options.dart';
// import 'package:zync_app/features/auth/presentation/pages/auth_wrapper.dart';
// import 'package:zync_app/core/splash/splash_screen.dart';
// import 'package:zync_app/core/services/initialization_service.dart';

// import 'core/global_keys.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
  
//   // OPTIMIZACIÓN CRÍTICA: Solo inicializar Firebase aquí
//   // Todo lo demás se hace en background después de mostrar UI
//   if (Firebase.apps.isEmpty) {
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//   }
  
//   // Mostrar app INMEDIATAMENTE
//   runApp(const ProviderScope(child: MyApp()));
// }

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
//   @override
//   void initState() {
//     super.initState();
//     // Registrar observer para detectar cambios de ciclo de vida
//     WidgetsBinding.instance.addObserver(this);
//   }

//   @override
//   void dispose() {
//     // Remover observer
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
    
//     // OPTIMIZACIÓN: No hacer nada pesado aquí
//     // El AuthWrapper maneja toda la lógica de reactivación
//     if (state == AppLifecycleState.resumed) {
//       print('📱 [App] Resumed from background');
//     } else if (state == AppLifecycleState.paused) {
//       print('📱 [App] Went to background');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final baseTheme = ThemeData(
//       brightness: Brightness.dark,
//       textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme),
//       colorScheme: ColorScheme.fromSeed(
//         seedColor: Colors.tealAccent,
//         brightness: Brightness.dark,
//       ),
//       useMaterial3: true,
//     );

//     return MaterialApp(
//       title: 'Zync App',
//       theme: baseTheme,
//       scaffoldMessengerKey: rootScaffoldMessengerKey,
//       // OPTIMIZACIÓN CRÍTICA: Splash screen que se muestra INMEDIATAMENTE
//       // mientras los servicios se inicializan en background
//       home: OptimizedSplashScreen(
//         onInitialize: () async {
//           // Inicializar todos los servicios en background
//           await InitializationService.initializeAllServices();
//         },
//         child: const AuthWrapper(),
//       ),
//     );
//   }
// }