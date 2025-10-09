// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zync_app/firebase_options.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
// import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
// import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
// import 'package:zync_app/features/auth/presentation/pages/sign_in_page.dart';
// import 'package:zync_app/dev_auth_test/dev_auth_test_page.dart';
import 'package:zync_app/features/auth/presentation/pages/auth_final_page.dart';
// import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
// import 'package:zync_app/features/circle/services/quick_status_service.dart'; // COMENTADO TEMPORALMENTE
import 'package:zync_app/core/widgets/status_widget.dart';
import 'package:zync_app/widgets/widget_service.dart';
import 'package:zync_app/quick_actions/quick_actions_service.dart';
import 'package:zync_app/notifications/notification_service.dart';
import 'package:zync_app/core/services/silent_functionality_coordinator.dart';
import 'package:zync_app/core/services/app_badge_service.dart';
import 'package:zync_app/core/services/status_service.dart';

import 'core/global_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- CORRECCIÓN DEFINITIVA ---
  // Se comprueba si Firebase ya tiene apps inicializadas.
  // Esto evita el error '[core/duplicate-app]' y el cuelgue.
  if (Firebase.apps.isEmpty) {
    print('>>> Firebase no está inicializado. Inicializando...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    print('>>> Firebase ya estaba inicializado. Saltando...');
  }

  print('>>> Después de la lógica de Firebase');
  await di.init();
  print('>>> Después de di.init()');
  // QuickStatusService.initialize(); // COMENTADO TEMPORALMENTE - parte de arquitectura antigua
  
  // Initialize the new widget service
  await StatusWidgetService.initialize();
  print('>>> Después de StatusWidgetService.initialize()');
  
  // Initialize Silent Functionality services
  await WidgetService.initialize();
  print('>>> Widget Service initialized');
  
  await QuickActionsService.initialize();
  print('>>> Quick Actions Service initialized');
  
  await NotificationService.initialize();
  print('>>> Notification Service initialized');
  
  await AppBadgeService.initialize();
  print('>>> App Badge Service initialized');
  
  runApp(const ProviderScope(child: MyApp()));
  print('>>> Después de runApp');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _firebaseReady = false;
  bool _silentFunctionalityReady = false;

  @override
  void initState() {
    super.initState();
    // Registrar observer para detectar cambios de ciclo de vida
    WidgetsBinding.instance.addObserver(this);
    _checkFirebase();
  }

  @override
  void dispose() {
    // Remover observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('>>> App Lifecycle State: $state');
    
    // Cuando la app vuelve del background, verificar estado de auth
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  Future<void> _handleAppResumed() async {
    print('>>> App resumed - verificando estado de auth y notificación');
    
    // Verificar si Firebase Auth sigue teniendo un usuario
    final currentUser = Firebase.apps.isNotEmpty 
        ? FirebaseAuth.instance.currentUser 
        : null;
        
    print('>>> Firebase Auth user: ${currentUser?.uid}');
    
    // Si hay usuario, inicializar listener de estados para badge
    if (currentUser != null) {
      try {
        await StatusService.initializeStatusListener();
        // Marcar como visto cuando el usuario abre la app
        await AppBadgeService.markAsSeen();
        print('>>> ✅ Status listener y badge inicializados');
      } catch (e) {
        print('>>> ❌ Error inicializando status listener: $e');
      }
    }
    
    // Si no hay usuario pero la funcionalidad silenciosa está activa, desactivarla
    if (currentUser == null && _silentFunctionalityReady) {
      print('>>> 🚨 Estado inconsistente detectado: Sin usuario pero funcionalidad activa');
      try {
        await SilentFunctionalityCoordinator.deactivateAfterLogout();
        await StatusService.disposeStatusListener();
        await AppBadgeService.clearBadge();
        print('>>> ✅ Funcionalidad silenciosa desactivada por estado inconsistente');
      } catch (e) {
        print('>>> ❌ Error desactivando funcionalidad silenciosa: $e');
      }
    }
  }

  Future<void> _checkFirebase() async {
    // Espera a que Firebase esté inicializado
    while (Firebase.apps.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    setState(() {
      _firebaseReady = true;
    });
    
    // Inicializar funcionalidad silenciosa una vez que Firebase esté listo
    _initializeSilentFunctionality();
  }

  Future<void> _initializeSilentFunctionality() async {
    try {
      // Esperar un poco para que el widget tree esté completamente construido
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        await SilentFunctionalityCoordinator.initialize(context);
        setState(() {
          _silentFunctionalityReady = true;
        });
        print('>>> Silent Functionality initialized: $_silentFunctionalityReady');
      }
    } catch (e) {
      print('>>> Error initializing Silent Functionality: $e');
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
      home: _firebaseReady
          ? const AuthFinalPage()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}