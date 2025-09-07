// lib/main.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
import 'package:zync_app/firebase_options.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
import 'package:zync_app/features/auth/presentation/pages/sign_in_page.dart';
import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
// Se confirma que este es el import correcto para la fachada del servicio.
import 'package:zync_app/features/circle/services/quick_status_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      log('Firebase ya estaba inicializado: $e');
    } else {
      rethrow;
    }
  }
  await di.init();
  // Se confirma que esta es la llamada correcta al método estático.
  QuickStatusService.initializeService();
  log("--- App Initialization Complete ---");
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log("[BUILD] MyApp rebuilding...");
    final authState = ref.watch(authProvider);
    log("[MyApp] Watching authState. Current state is: $authState");

    return MaterialApp(
      title: 'Zync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: switch (authState) {
        Authenticated() => const HomePage(),
        Unauthenticated() || AuthError() => const SignInPage(),
        _ => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }
}