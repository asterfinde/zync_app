// lib/features/auth/presentation/provider/auth_provider.dart

import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../../../../core/di/injection_container.dart';
import '../../../../core/usecases/usecase.dart';

import '../../domain/usecases/sign_in_or_register.dart';
import '../../domain/usecases/sign_out.dart';
import 'auth_state.dart';
import '../../data/models/user_model.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final firebase.FirebaseAuth _firebaseAuth;
  final SignInOrRegister _signInOrRegister;
  final SignOut _signOut;

  AuthNotifier({
    required firebase.FirebaseAuth firebaseAuth,
    required SignInOrRegister signInOrRegister,
    required SignOut signOut,
  })  : _firebaseAuth = firebaseAuth,
        _signInOrRegister = signInOrRegister,
        _signOut = signOut,
        super(AuthInitial()) {
    log("[AuthNotifier] Initializing and listening to authStateChanges...");
    _firebaseAuth.authStateChanges().listen((user) {
      log("[AuthNotifier] authStateChanges stream received user: ${user?.uid}");
      if (user != null) {
        state = Authenticated(UserModel(
          uid: user.uid,
          email: user.email ?? '', // Valor por defecto para email
          name: user.displayName ?? 'Usuario', // Valor por defecto para nombre
        ));
      } else {
        state = Unauthenticated();
      }
    });
  }

  Future<void> signInOrRegister(String email, String password) async {
    log("[AuthNotifier] Attempting to signInOrRegister for email: $email");
    state = AuthLoading();
    final params = SignInOrRegisterParams(email: email, password: password);
    final result = await _signInOrRegister(params);
    result.fold(
      (failure) {
        log("[AuthNotifier] signInOrRegister FAILED: ${failure.message}");
        state = AuthError(failure.message);
      },
      (user) {
        log("[AuthNotifier] signInOrRegister SUCCEEDED for user: ${user.uid}");
        // El listener de authStateChanges se encargará de actualizar el estado a Authenticated.
        // No es estrictamente necesario poner el estado aquí, pero lo hacemos para una respuesta más rápida de la UI.
        state = Authenticated(user);
      },
    );
  }

  Future<void> signOut() async {
    log("[AuthNotifier] Attempting to signOut...");
    state = AuthLoading();
    final result = await _signOut(NoParams());
    result.fold(
      (failure) {
        log("[AuthNotifier] signOut FAILED: ${failure.message}");
        state = AuthError(failure.message);
      },
      (_) async {
        log("[AuthNotifier] signOut SUCCEEDED. Calling Firebase signOut.");
        await _firebaseAuth.signOut();
        // El listener de authStateChanges pondrá Unauthenticated automáticamente
      },
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    firebaseAuth: firebase.FirebaseAuth.instance,
    signInOrRegister: sl<SignInOrRegister>(),
    signOut: sl<SignOut>(),
  );
});