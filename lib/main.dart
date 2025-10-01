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
import 'package:zync_app/features/auth/presentation/pages/auth_final_page.dart';
// import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
// import 'package:zync_app/features/circle/services/quick_status_service.dart'; // COMENTADO TEMPORALMENTE
import 'package:zync_app/core/widgets/status_widget.dart';

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
  
  runApp(const ProviderScope(child: MyApp()));
  print('>>> Después de runApp');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _firebaseReady = false;

  @override
  void initState() {
    super.initState();
    _checkFirebase();
  }

  Future<void> _checkFirebase() async {
    // Espera a que Firebase esté inicializado
    while (Firebase.apps.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    setState(() {
      _firebaseReady = true;
    });
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