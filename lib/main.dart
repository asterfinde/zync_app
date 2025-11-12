// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zync_app/firebase_options.dart';
import 'package:zync_app/features/auth/presentation/pages/auth_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
import 'package:zync_app/core/cache/persistent_cache.dart'; // CACHE PERSISTENTE
import 'package:zync_app/core/utils/performance_tracker.dart'; // PERFORMANCE TRACKING
import 'package:zync_app/core/services/session_cache_service.dart'; // FASE 2B: Session Cache (fallback)
import 'package:zync_app/core/services/native_state_bridge.dart'; // FASE 3: Native State (primario) (fallback)

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

  // 🎯 RENDERIZAR UI (con cache ya disponible)
  runApp(const ProviderScope(child: MyApp()));

  // ⏳ LAZY: Inicializar servicios NO críticos DESPUÉS del primer frame
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    print('🔄 [main] Inicializando servicios secundarios en background...');
    
    // DI en background
    PerformanceTracker.start('DI Init');
    await di.init(); 
    PerformanceTracker.end('DI Init');
    print('✅ [main] DI inicializado.');
    
    // Cache en background
    PerformanceTracker.start('Cache Init');
    await PersistentCache.init();
    PerformanceTracker.end('Cache Init');
    print('✅ [main] Cache inicializado.');
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
      // CACHE-FIRST: Eliminar splash screen, mostrar AuthWrapper directamente
      // El cache hará que la UI aparezca instantáneamente
      home: const AuthWrapper(),
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