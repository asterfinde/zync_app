// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zync_app/firebase_options.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
// import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
// import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
// import 'package:zync_app/features/auth/presentation/pages/sign_in_page.dart';
// import 'package:zync_app/dev_auth_test/dev_auth_test_page.dart';
import 'package:zync_app/features/auth/presentation/pages/auth_wrapper.dart';
// import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
// import 'package:zync_app/features/circle/services/quick_status_service.dart'; // COMENTADO TEMPORALMENTE
import 'package:zync_app/core/widgets/status_widget.dart';
import 'package:zync_app/widgets/widget_service.dart';
import 'package:zync_app/quick_actions/quick_actions_service.dart';
import 'package:zync_app/notifications/notification_service.dart';
import 'package:zync_app/core/services/silent_functionality_coordinator.dart';
import 'package:zync_app/core/services/app_badge_service.dart';

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
  
  // Inicializar Silent Functionality Coordinator ANTES de runApp
  // Esto asegura que esté listo cuando AuthWrapper lo necesite
  await SilentFunctionalityCoordinator.initializeServices();
  print('>>> Silent Functionality Coordinator services initialized');
  
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
    
    // El AuthWrapper maneja toda la lógica de autenticación y reactivación
    // No hacemos nada aquí para evitar duplicaciones
    if (state == AppLifecycleState.resumed) {
      print('>>> App resumed');
    }
  }

  Future<void> _checkFirebase() async {
    // Espera a que Firebase esté inicializado
    while (Firebase.apps.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (mounted) {
      setState(() {
        _firebaseReady = true;
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
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: _firebaseReady
          ? const AuthWrapper()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}