// lib/features/auth/presentation/pages/sign_in_page.dart

import 'dart:developer';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/global_keys.dart';
import '../provider/auth_provider.dart';
import '../provider/auth_state.dart';
import '../widgets/auth_form.dart';

// import 'package:zync_app/features/circle/presentation/pages/home_page.dart';



class SignInPage extends ConsumerWidget {
  // --- FUNCIÓN DE LIMPIEZA MASIVA ---
  const SignInPage({super.key});

  void _submitAuthForm(WidgetRef ref, String email, String password, String nickname) {
    log("[SignInPage] _submitAuthForm called. Triggering signInOrRegister...");
    // Si nickname está vacío, es login; si no, es registro
    ref.read(authProvider.notifier).signInOrRegister(email, password, nickname: nickname);
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {

    log("[BUILD] SignInPage rebuilding...");
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthError) {
        log("[SignInPage] Listener detected AuthError: ${next.message}");
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      // Ya no se navega manualmente a HomePage. El widget raíz controla la pantalla.
    });

    final authState = ref.watch(authProvider);
    log("[SignInPage] Watching authState. Current state is: $authState");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zync'),
        actions: [],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: AuthForm(
              submitFn: (email, password, nickname) => _submitAuthForm(ref, email, password, nickname),
              isLoading: authState is AuthLoading,
            ),
          ),
        ),
      ),
    );
  }
}