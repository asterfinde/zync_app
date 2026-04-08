// lib/features/auth/presentation/provider/auth_provider.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../../../../core/services/silent_functionality_coordinator.dart';
import '../../../../core/services/native_state_bridge.dart'; // FASE 3: Sincronización Flutter↔Kotlin
import '../../../../services/auth_service.dart'; // 🔥 SIMPLIFICADO: AuthService directo
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final firebase.FirebaseAuth _firebaseAuth;
  final AuthService _authService; // 🔥 SIMPLIFICADO: Un solo servicio
  StreamSubscription? _authSubscription;

  bool _getUserRetryInProgress = false;

  AuthNotifier({
    required firebase.FirebaseAuth firebaseAuth,
    required AuthService authService,
  })  : _firebaseAuth = firebaseAuth,
        _authService = authService,
        super(AuthInitial()) {
    log("[AuthNotifier] Initializing. The stream is the ONLY source of truth.");
    _authSubscription =
        _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(firebase.User? firebaseUser) async {
    log("[AuthNotifier] [STREAM] Stream reported user: ${firebaseUser?.uid}");
    log("[AuthNotifier] [STREAM] _onAuthStateChanged: firebaseUser = ${firebaseUser?.uid}, email = ${firebaseUser?.email}");
    try {
      if (firebaseUser != null) {
        log("[AuthNotifier] [STREAM] FirebaseUser existe. Llamando a getCurrentUser...");

        // 🔥 SIMPLIFICADO: try/catch en vez de Either/fold
        try {
          final user = await _authService.getCurrentUser();
          log("[AuthNotifier] [STREAM] getCurrentUser SUCCESS. user: $user");

          if (user != null) {
            // 🚀 FASE 3: Sincronizar estado con Kotlin nativo (no bloquea el flujo)
            NativeStateBridge.setUserId(
              userId: user.uid,
              email: user.email,
              circleId: '', // circleId se obtiene de Firestore aparte
            ).catchError((e) {
              log("[AuthNotifier] ⚠️ NativeState sync error (esperado en iOS): $e");
            });

            log("[AuthNotifier] [STREAM] User details fetched successfully. State -> Authenticated. user.nickname: ${user.nickname}, user.email: ${user.email}");
            state = Authenticated(user);
          } else {
            log("[AuthNotifier] [STREAM] AuthService returned a null user. State -> Unauthenticated");
            state = Unauthenticated();
          }
        } catch (e) {
          log("[AuthNotifier] [STREAM] getCurrentUser FAILURE: $e");
          if (_getUserRetryInProgress) {
            // Ya se reintentó — red no disponible, ceder el paso al login
            log("[AuthNotifier] [STREAM] Reintento fallido. Yendo a Unauthenticated.");
            _getUserRetryInProgress = false;
            state = AuthError("No pudimos cargar tus datos. Verifica tu conexión.");
            Future.delayed(const Duration(seconds: 2), () {
              if (!mounted) return;
              if (state is AuthError) state = Unauthenticated();
            });
          } else {
            // Primer fallo — puede ser error de red transitorio en cold start
            _getUserRetryInProgress = true;
            log("[AuthNotifier] [STREAM] Reintentando en 5s (posible cold-start)...");
            state = AuthLoading();
            Future.delayed(const Duration(seconds: 5), () {
              if (!mounted) return;
              if (state is AuthLoading) _onAuthStateChanged(firebaseUser);
            });
          }
        }
      } else {
        // Si el stream emite null tras la inicialización, avanzar a Unauthenticated
        log("[AuthNotifier] Stream reported no user. State -> Unauthenticated");

        // 🚀 FASE 3: Limpiar estado nativo (logout) - no bloquea
        NativeStateBridge.setUserId(userId: '').catchError((e) {
          log("[AuthNotifier] ⚠️ NativeState clear error (esperado en iOS): $e");
        });

        // NUEVO: Desactivar funcionalidad silenciosa cuando el usuario se desloguea
        log("[AuthNotifier] 🔴 Usuario deslogueado vía stream, desactivando funcionalidad silenciosa...");
        try {
          await SilentFunctionalityCoordinator.deactivateAfterLogout();
          log("[AuthNotifier] 🔴 Funcionalidad silenciosa desactivada correctamente");
        } catch (e) {
          log("[AuthNotifier] ❌ Error desactivando funcionalidad silenciosa: $e");
        }

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

  Future<void> signInOrRegister(String email, String password,
      {String nickname = ''}) async {
    log("[AuthNotifier] [ACTION] Triggering signInOrRegister for email: $email, nickname: $nickname");
    state = AuthLoading();

    // 🔥 SIMPLIFICADO: try/catch en vez de Either/fold
    try {
      await _authService.signInOrRegister(
        email: email,
        password: password,
        nickname: nickname,
      );

      log("[AuthNotifier] [ACTION] signInOrRegister SUCCEEDED. Forzando recarga de usuario desde Firestore...");

      try {
        final freshUser = await _authService.getCurrentUser();
        log("[AuthNotifier] [ACTION] getCurrentUser tras login/registro SUCCESS. freshUser: $freshUser");

        if (freshUser != null) {
          // 🚀 FASE 3: Sincronizar estado con Kotlin tras login/registro (no bloquea)
          NativeStateBridge.setUserId(
            userId: freshUser.uid,
            email: freshUser.email,
            circleId: '', // circleId se obtiene de Firestore aparte
          ).catchError((e) {
            log("[AuthNotifier] ⚠️ NativeState sync error (esperado en iOS): $e");
          });

          log("[AuthNotifier] [ACTION] Usuario recargado tras login/registro. State -> Authenticated. Nickname: ${freshUser.nickname}, Email: ${freshUser.email}");
          state = Authenticated(freshUser);
        } else {
          log("[AuthNotifier] [ACTION] Usuario recargado es null tras login/registro. State -> Unauthenticated");
          state = Unauthenticated();
        }
      } catch (e) {
        log("[AuthNotifier] [ACTION] getCurrentUser tras login/registro FAILED: $e");
        state = AuthError("Error cargando datos del usuario: $e");
      }
    } catch (e) {
      if (nickname.isNotEmpty) {
        log("[AuthNotifier] [ACTION] Registro fallido para $email. Borrando usuario Auth temporal si existe...");
        try {
          await _firebaseAuth.currentUser?.delete();
        } catch (deleteError) {
          log("[AuthNotifier] [ACTION] No se pudo eliminar el usuario temporal tras fallo de registro: $deleteError");
        }
      }
      log("[AuthNotifier] [ACTION] signInOrRegister FAILED: $e");
      state = AuthError("Error de autenticación: $e");
    }
  }

  Future<void> signOut() async {
    log("[AuthNotifier] Triggering signOut...");
    state = AuthLoading();

    // 🔥 SIMPLIFICADO: try/catch en vez de Either/fold
    try {
      await _authService.signOut();
      log("[AuthNotifier] signOut SUCCEEDED. Handing off to the stream listener.");
    } catch (e) {
      log("[AuthNotifier] signOut FAILED: $e");
      state = AuthError("Error cerrando sesión: $e");
    }
  }

  @override
  void dispose() {
    log("[AuthNotifier] Disposing AuthNotifier and canceling subscription.");
    _authSubscription?.cancel();
    super.dispose();
  }
}

// 🔥 SIMPLIFICADO: AuthProvider usa AuthService en vez de GetIt
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthNotifier(
    firebaseAuth: firebase.FirebaseAuth.instance,
    authService: authService,
  );
});
