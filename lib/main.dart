// lib/main.dart

import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/injection_container.dart' as di;
import 'features/auth/presentation/pages/sign_in_page.dart';
import 'features/auth/presentation/provider/auth_provider.dart';
import 'features/auth/presentation/provider/auth_state.dart';
import 'features/circle/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await di.init();
  log("--- App Initialization Complete ---");
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log("[BUILD] MyApp rebuilding...");

    ref.listen<AuthState>(authProvider, (previous, next) {
      log('[STATE_CHANGE] Auth state changed from: $previous to: $next');
    });

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