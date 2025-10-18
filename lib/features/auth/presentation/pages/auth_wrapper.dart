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
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mostrar loading mientras se verifica el estado de autenticación
        if (snapshot.connectionState == ConnectionState.waiting) {
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
          print('✅ [AuthWrapper] Usuario autenticado detectado: ${user.uid}');
          print('✅ [AuthWrapper] Email: ${user.email}');
          
          // Inicializar funcionalidad silenciosa si el usuario está autenticado
          _initializeSilentFunctionalityIfNeeded();
          
          return const HomePage();
        } else {
          // Usuario NO autenticado → mostrar pantalla de login
          print('🔴 [AuthWrapper] No hay usuario autenticado');
          
          // Asegurar que la funcionalidad silenciosa esté desactivada
          _cleanupSilentFunctionalityIfNeeded();
          
          return const AuthFinalPage();
        }
      },
    );
  }

  /// Inicializa la funcionalidad silenciosa si el usuario está autenticado
  /// Solo se ejecuta una vez al detectar usuario autenticado
  void _initializeSilentFunctionalityIfNeeded() async {
    try {
      print('🟢 [AuthWrapper] Inicializando funcionalidad silenciosa...');
      
      // Activar funcionalidad silenciosa
      await SilentFunctionalityCoordinator.activateAfterLogin();
      print('🟢 [AuthWrapper] Funcionalidad silenciosa activada');
      
      // Inicializar listener de estados para badge
      await StatusService.initializeStatusListener();
      print('🟢 [AuthWrapper] Status listener inicializado');
      
      // Marcar como visto cuando el usuario regresa a la app
      await AppBadgeService.markAsSeen();
      print('🟢 [AuthWrapper] Badge marcado como visto');
      
    } catch (e) {
      print('❌ [AuthWrapper] Error inicializando funcionalidad silenciosa: $e');
    }
  }

  /// Limpia la funcionalidad silenciosa cuando no hay usuario autenticado
  void _cleanupSilentFunctionalityIfNeeded() async {
    try {
      print('🔴 [AuthWrapper] Limpiando funcionalidad silenciosa...');
      
      // Desactivar funcionalidad silenciosa
      await SilentFunctionalityCoordinator.deactivateAfterLogout();
      print('🔴 [AuthWrapper] Funcionalidad silenciosa desactivada');
      
      // Limpiar listener de estados
      await StatusService.disposeStatusListener();
      print('🔴 [AuthWrapper] Status listener limpiado');
      
      // Limpiar badge
      await AppBadgeService.clearBadge();
      print('🔴 [AuthWrapper] Badge limpiado');
      
    } catch (e) {
      print('❌ [AuthWrapper] Error limpiando funcionalidad silenciosa: $e');
    }
  }
}
