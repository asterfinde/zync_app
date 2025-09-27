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
    log("[AuthNotifier] Initializing. The stream is the ONLY source of truth.");
    _authSubscription = _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(firebase.User? firebaseUser) async {
    log("[AuthNotifier] [STREAM] Stream reported user: \\${firebaseUser?.uid}");
    log("[AuthNotifier] [STREAM] _onAuthStateChanged: firebaseUser = ${firebaseUser?.uid}, email = ${firebaseUser?.email}");
    try {
      if (firebaseUser != null) {
        log("[AuthNotifier] [STREAM] FirebaseUser existe. Llamando a _getCurrentUser...");
        final result = await _getCurrentUser(NoParams());
        result.fold(
          (failure) {
            log("[AuthNotifier] [STREAM] getCurrentUser FAILURE: \\${failure.message}");
            log("[AuthNotifier] [STREAM] getCurrentUser FAILURE (detalle): $failure");
            state = AuthError("No pudimos cargar tus datos. Intenta de nuevo.");
            Future.delayed(const Duration(seconds: 2), () {
              if (!mounted) return;
              if (state is AuthError) {
                state = Unauthenticated();
              }
            });
          },
          (user) {
            log("[AuthNotifier] [STREAM] getCurrentUser SUCCESS. user: $user");
            if (user != null) {
              log("[AuthNotifier] [STREAM] User details fetched successfully. State -> Authenticated. user.nickname: ${user.nickname}, user.email: ${user.email}");
              state = Authenticated(user);
            } else {
              log("[AuthNotifier] [STREAM] UseCase returned a null user. State -> Unauthenticated");
              state = Unauthenticated();
            }
          },
        );
      } else {
        // Si el stream emite null tras la inicialización, avanzar a Unauthenticated
        log("[AuthNotifier] Stream reported no user. State -> Unauthenticated");
        state = Unauthenticated();
      }
    } catch (e) {
      log("[AuthNotifier] EXCEPTION in _onAuthStateChanged: $e");
      state = AuthError("Error inesperado de autenticación. Intenta de nuevo.");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) state = Unauthenticated();
      });
    }
  }

  Future<void> signInOrRegister(String email, String password, {String nickname = ''}) async {
    log("[AuthNotifier] [ACTION] Triggering signInOrRegister for email: $email, nickname: $nickname");
    state = AuthLoading();
    final params = SignInOrRegisterParams(email: email, password: password, nickname: nickname);
    final result = await _signInOrRegister(params);

    await result.fold(
      (failure) async {
        if (nickname.isNotEmpty) {
          log("[AuthNotifier] [ACTION] Registro fallido para $email. Borrando usuario Auth temporal si existe...");
          try {
            await _firebaseAuth.currentUser?.delete();
          } catch (e) {
            log("[AuthNotifier] [ACTION] No se pudo eliminar el usuario temporal tras fallo de registro: $e");
          }
        }
        log("[AuthNotifier] [ACTION] signInOrRegister FAILED: ${failure.message}");
        log("[AuthNotifier] [ACTION] signInOrRegister FAILURE (detalle): $failure");
        state = AuthError(failure.message);
      },
      (user) async {
        log("[AuthNotifier] [ACTION] signInOrRegister SUCCEEDED. Forzando recarga de usuario desde Firestore...");
        final currentUserResult = await _getCurrentUser(NoParams());
        await currentUserResult.fold(
          (failure) async {
            log("[AuthNotifier] [ACTION] getCurrentUser tras login/registro FAILED: ${failure.message}");
            log("[AuthNotifier] [ACTION] getCurrentUser tras login/registro FAILURE (detalle): $failure");
            state = AuthError(failure.message);
          },
          (freshUser) async {
            log("[AuthNotifier] [ACTION] getCurrentUser tras login/registro SUCCESS. freshUser: $freshUser");
            if (freshUser != null) {
              log("[AuthNotifier] [ACTION] Usuario recargado tras login/registro. State -> Authenticated. Nickname: ${freshUser.nickname}, Email: ${freshUser.email}");
              state = Authenticated(freshUser);
            } else {
              log("[AuthNotifier] [ACTION] Usuario recargado es null tras login/registro. State -> Unauthenticated");
              state = Unauthenticated();
            }
          },
        );
      },
    );
  }

  Future<void> signOut() async {
    log("[AuthNotifier] Triggering signOut...");
    state = AuthLoading();
    final result = await _signOut(NoParams());
    result.fold(
      (failure) {
        log("[AuthNotifier] signOut FAILED: ${failure.message}");
        state = AuthError(failure.message);
      },
      (_) {
        log("[AuthNotifier] signOut SUCCEEDED. Handing off to the stream listener.");
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

