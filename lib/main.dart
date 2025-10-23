// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zync_app/firebase_options.dart';
import 'package:zync_app/features/auth/presentation/pages/auth_wrapper.dart';
import 'package:zync_app/core/splash/splash_screen.dart';
import 'package:zync_app/core/services/initialization_service.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
import 'package:zync_app/core/cache/persistent_cache.dart'; // CACHE PERSISTENTE

import 'core/global_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // OPTIMIZACIÓN CRÍTICA: Inicializar Firebase y GetIt aquí, en el main isolate
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
  // Inicializar GetIt (DI) ANTES de runApp()
  print('🚀 [main] Inicializando Dependency Injection...');
  await di.init(); 
  print('✅ [main] Dependency Injection inicializado.');
  
  // CACHE-FIRST: Inicializar cache persistente
  print('🚀 [main] Inicializando PersistentCache...');
  await PersistentCache.init();
  print('✅ [main] PersistentCache inicializado.');

  // Mostrar app INMEDIATAMENTE
  runApp(const ProviderScope(child: MyApp()));
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
    if (state == AppLifecycleState.resumed) {
      print('📱 [App] Resumed from background');
    } else if (state == AppLifecycleState.paused) {
      print('📱 [App] Went to background - Guardando cache...');
      // CACHE-FIRST: Guardar cache cuando la app se minimiza
      // (El InCircleView guardará su propio estado en su dispose())
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
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: OptimizedSplashScreen(
        // Ahora solo inicializa los *otros* servicios en background
        onInitialize: InitializationService.initializeNonDIServices, // <-- CAMBIAR NOMBRE DE FUNCIÓN
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