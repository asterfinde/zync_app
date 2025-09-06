// lib/features/auth/presentation/provider/auth_provider.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../../../../core/di/injection_container.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_in_or_register.dart';
import '../../domain/usecases/sign_out.dart';
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final firebase.FirebaseAuth _firebaseAuth;
  final GetCurrentUser _getCurrentUser;
  final SignInOrRegister _signInOrRegister;
  final SignOut _signOut;
  StreamSubscription? _authSubscription;

  AuthNotifier({
    required firebase.FirebaseAuth firebaseAuth,
    required GetCurrentUser getCurrentUser,
    required SignInOrRegister signInOrRegister,
    required SignOut signOut,
  })  : _firebaseAuth = firebaseAuth,
        _getCurrentUser = getCurrentUser,
        _signInOrRegister = signInOrRegister,
        _signOut = signOut,
        super(AuthInitial()) {
    log("[AuthNotifier] Initializing and listening to authStateChanges...");
    _authSubscription = _firebaseAuth.authStateChanges().listen((firebaseUser) async {
      log("[AuthNotifier] authStateChanges stream received user: ${firebaseUser?.uid}");
      if (firebaseUser != null) {
        final result = await _getCurrentUser(NoParams());
        result.fold(
          (failure) {
            log("[AuthNotifier] Could not get user details: ${failure.message}");
            state = Unauthenticated();
          },
          (user) {
            // TU CORRECCIÓN: Se mantiene el null-check por seguridad.
            if (user != null) {
              state = Authenticated(user);
            } else {
              // Si el caso de uso devolviera null en el lado exitoso, lo manejamos.
              log("[AuthNotifier] UseCase returned a null user on success. Setting to Unauthenticated.");
              state = Unauthenticated();
            }
          },
        );
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
      (_) {
        log("[AuthNotifier] signOut SUCCEEDED via UseCase.");
        // El listener de authStateChanges se encargará de actualizar el estado a Unauthenticated.
      },
    );
  }

  @override
  void dispose() {
    log("[AuthNotifier] Disposing AuthNotifier and canceling subscription.");
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    firebaseAuth: firebase.FirebaseAuth.instance,
    getCurrentUser: sl<GetCurrentUser>(),
    signInOrRegister: sl<SignInOrRegister>(),
    signOut: sl<SignOut>(),
  );
});

