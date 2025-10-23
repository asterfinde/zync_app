// lib/features/auth/presentation/pages/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
import 'package:zync_app/features/auth/presentation/pages/auth_final_page.dart';
import 'package:zync_app/core/services/silent_functionality_coordinator.dart';
import 'package:zync_app/core/services/status_service.dart';
import 'package:zync_app/core/services/app_badge_service.dart';

/// AuthWrapper: Verifica el estado de autenticación y muestra la pantalla correcta
/// 
/// Esta clase resuelve el problema crítico de minimización:
/// - Cuando la app se minimiza y regresa, NO cierra la sesión del usuario
/// - Detecta si hay un usuario autenticado en Firebase Auth
/// - Si está autenticado → HomePage
/// - Si NO está autenticado → AuthFinalPage
/// 
/// OPTIMIZACIÓN: Usa StatefulWidget para evitar re-inicializar servicios
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isSilentFunctionalityInitialized = false;
  String? _lastAuthenticatedUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mostrar loading SOLO en la conexión inicial (no en rebuilds)
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1EE9A4)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Verificando sesión...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Verificar si hay un error
        if (snapshot.hasError) {
          print('❌ [AuthWrapper] Error en stream de autenticación: ${snapshot.error}');
          return const AuthFinalPage();
        }

        final user = snapshot.data;

        if (user != null) {
          // Usuario autenticado → ir a HomePage
          
          // OPTIMIZACIÓN: Solo inicializar si el usuario cambió o es la primera vez
          if (_lastAuthenticatedUserId != user.uid) {
            print('✅ [AuthWrapper] Usuario autenticado: ${user.uid}');
            _lastAuthenticatedUserId = user.uid;
            _initializeSilentFunctionalityIfNeeded(user.uid);
          }
          
          return const HomePage();
        } else {
          // Usuario NO autenticado → mostrar pantalla de login
          
          // OPTIMIZACIÓN: Solo limpiar si había un usuario antes
          if (_lastAuthenticatedUserId != null) {
            print('🔴 [AuthWrapper] Usuario desautenticado');
            _lastAuthenticatedUserId = null;
            _isSilentFunctionalityInitialized = false;
            _cleanupSilentFunctionalityIfNeeded();
          }
          
          return const AuthFinalPage();
        }
      },
    );
  }

  /// Inicializa la funcionalidad silenciosa si el usuario está autenticado
  /// OPTIMIZACIÓN: Solo se llama UNA VEZ cuando cambia el usuario
  void _initializeSilentFunctionalityIfNeeded(String userId) {
    // Evitar re-inicializar si ya está inicializado para este usuario
    if (_isSilentFunctionalityInitialized) {
      print('⚡ [AuthWrapper] Funcionalidad silenciosa ya inicializada para este usuario, saltando...');
      return;
    }

    // Marcar inmediatamente para evitar llamadas duplicadas
    _isSilentFunctionalityInitialized = true;

    // CACHE-FIRST: Ejecutar activación en background sin await (NO BLOQUEAR UI)
    // InitializationService ya se inicializó en main.dart, no necesitamos esperar
    Future.microtask(() async {
      try {
        print('🟢 [AuthWrapper] Activando funcionalidad silenciosa en background...');
        
        // Solo activar la notificación persistente (los servicios ya están inicializados en main.dart)
        await SilentFunctionalityCoordinator.activateAfterLogin();
        
        // Inicializar listener de estados para badge (solo si no está inicializado)
        await StatusService.initializeStatusListener();
        
        // Marcar como visto
        await AppBadgeService.markAsSeen();
        
        print('✅ [AuthWrapper] Funcionalidad silenciosa activada en background');
        
      } catch (e) {
        print('❌ [AuthWrapper] Error activando funcionalidad silenciosa: $e');
        _isSilentFunctionalityInitialized = false; // Reintentar si falló
      }
    });
  }

  /// Limpia la funcionalidad silenciosa cuando no hay usuario autenticado
  /// OPTIMIZACIÓN: Se ejecuta en background, NO bloquea la UI
  void _cleanupSilentFunctionalityIfNeeded() {
    // Ejecutar en background para NO bloquear la UI
    Future.microtask(() async {
      try {
        print('🔴 [AuthWrapper] Limpiando funcionalidad silenciosa en background...');
        
        // Desactivar funcionalidad silenciosa
        await SilentFunctionalityCoordinator.deactivateAfterLogout();
        
        // Limpiar listener de estados
        await StatusService.disposeStatusListener();
        
        // Limpiar badge
        await AppBadgeService.clearBadge();
        
        print('🔴 [AuthWrapper] Funcionalidad silenciosa limpiada exitosamente');
        
      } catch (e) {
        print('❌ [AuthWrapper] Error limpiando funcionalidad silenciosa: $e');
      }
    });
  }
}
