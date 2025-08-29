// lib/features/auth/presentation/pages/sign_in_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/auth_provider.dart';
import '../provider/auth_state.dart';
import '../widgets/auth_form.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  void _submitAuthForm(WidgetRef ref, String email, String password) {
    log("[SignInPage] _submitAuthForm called. Triggering signInOrRegister...");
    ref.read(authProvider.notifier).signInOrRegister(email, password);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log("[BUILD] SignInPage rebuilding...");

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthError) {
        log("[SignInPage] Listener detected AuthError: ${next.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    final authState = ref.watch(authProvider);
    log("[SignInPage] Watching authState. Current state is: $authState");

    return Scaffold(
      appBar: AppBar(title: const Text('Zync')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: AuthForm(
              submitFn: (email, password) => _submitAuthForm(ref, email, password),
              isLoading: authState is AuthLoading,
            ),
          ),
        ),
      ),
    );
  }
}