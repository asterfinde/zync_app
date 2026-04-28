// lib/features/auth/presentation/pages/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/features/circle/presentation/pages/home_page.dart';
import 'package:nunakin_app/features/auth/presentation/pages/auth_final_page.dart';
import 'package:nunakin_app/core/services/silent_functionality_coordinator.dart';
import 'package:nunakin_app/core/services/status_service.dart';
import 'package:nunakin_app/core/services/app_badge_service.dart';
import 'package:nunakin_app/core/services/session_cache_service.dart';
import 'package:nunakin_app/notifications/notification_service.dart';
import 'package:app_settings/app_settings.dart';
import 'package:nunakin_app/services/circle_service.dart';

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
        // Fast render: Firebase Auth persiste localmente (igual que apps nativas).
        // currentUser es sincrónico (0ms) — elimina la necesidad de un cache propio.
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

        // Loading solo cuando genuinamente no se conoce el estado aún
        if (snapshot.connectionState == ConnectionState.waiting && user == null) {
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
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('❌ [AuthWrapper] Error en stream de autenticación: ${snapshot.error}');
          return const AuthFinalPage();
        }

        if (user != null) {
          if (_lastAuthenticatedUserId != user.uid) {
            print('✅ [AuthWrapper] Usuario autenticado: ${user.uid}');
            _lastAuthenticatedUserId = user.uid;
            _initializeSilentFunctionalityIfNeeded(user.uid);
            _verifyUserAccountOnServer(user);
          }
          return const HomePage();
        } else {
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

  /// Verifica contra el servidor que la cuenta sigue existiendo en Firebase.
  /// Fire-and-forget: si falla, cierra sesión y el stream detecta el cambio.
  void _verifyUserAccountOnServer(User user) {
    Future.microtask(() async {
      try {
        await user.reload();
        if (FirebaseAuth.instance.currentUser == null) {
          print('⚠️ [AuthWrapper] Cuenta eliminada en servidor, cerrando sesión...');
          await SessionCacheService.clearSession();
          if (mounted) {
            setState(() {
              _lastAuthenticatedUserId = null;
              _isSilentFunctionalityInitialized = false;
            });
          }
        }
      } catch (e) {
        print('⚠️ [AuthWrapper] Token inválido al verificar cuenta: $e — cerrando sesión...');
        await FirebaseAuth.instance.signOut();
        await SessionCacheService.clearSession();
      }
    });
  }

  /// Inicializa la funcionalidad silenciosa si el usuario está autenticado
  /// OPTIMIZACIÓN: Solo se llama UNA VEZ cuando cambia el usuario
  void _initializeSilentFunctionalityIfNeeded(String userId) {
    // Evitar re-inicializar si ya está inicializado para este usuario
    if (_isSilentFunctionalityInitialized) {
      print(
          '⚡ [AuthWrapper] Funcionalidad silenciosa ya inicializada para este usuario, saltando...');
      return;
    }

    // Marcar inmediatamente para evitar llamadas duplicadas
    _isSilentFunctionalityInitialized = true;

    // CACHE-FIRST: Ejecutar activación en background sin await (NO BLOQUEAR UI)
    // InitializationService ya se inicializó en main.dart, no necesitamos esperar
    Future.microtask(() async {
      try {
        print(
            '🟢 [AuthWrapper] Activando funcionalidad silenciosa en background...');

        // Solo activar la notificación persistente (los servicios ya están inicializados en main.dart)
        await SilentFunctionalityCoordinator.activateAfterLogin(context);

        // Inicializar listener de estados para badge (solo si no está inicializado)
        await StatusService.initializeStatusListener();

        // Marcar como visto
        await AppBadgeService.markAsSeen();

        print(
            '✅ [AuthWrapper] Funcionalidad silenciosa activada en background');

        // Point 2: Verificar permisos después de activar funcionalidad silenciosa
        await _checkNotificationPermissionsAfterAutoLogin(context);
      } catch (e) {
        print('❌ [AuthWrapper] Error activando funcionalidad silenciosa: $e');
        _isSilentFunctionalityInitialized = false; // Reintentar si falló
      }
    });
  }

  // Point 2: Verificar permisos de notificación después del auto-login
  Future<void> _checkNotificationPermissionsAfterAutoLogin(
      BuildContext checkContext) async {
    // Esperar un poco para que la UI esté completamente renderizada
    await Future.delayed(const Duration(milliseconds: 500));

    if (!checkContext.mounted) {
      print('[POINT 2 AUTO] Context no mounted - cancelando verificación');
      return;
    }

    print('');
    print('=== [POINT 2 AUTO] VERIFICACIÓN DE PERMISOS (AUTO-LOGIN) ===');

    try {
      // VERIFICAR PRIMERO SI EL USUARIO PERTENECE A UN CÍRCULO
      print(
          '[POINT 2 AUTO] 🔍 Verificando si el usuario pertenece a un círculo...');
      final circleService = CircleService();
      final userCircle = await circleService.getUserCircle();

      if (userCircle == null) {
        print('[POINT 2 AUTO] ⚠️ Usuario NO pertenece a un círculo');
        print(
            '[POINT 2 AUTO] ⚠️ NO se verificarán permisos ni se mostrará modal');
        return;
      }

      print(
          '[POINT 2 AUTO] ✅ Usuario pertenece al círculo: ${userCircle.name}');
      final hasPermission = await NotificationService.hasPermission();

      print('[POINT 2 AUTO] 🔍 Resultado hasPermission: $hasPermission');

      if (!hasPermission && checkContext.mounted) {
        print(
            '[POINT 2 AUTO] ⚠️ Permisos DENEGADOS - Mostrando modal informativo');
        await _showPermissionDeniedDialog(checkContext);
      } else {
        print(
            '[POINT 2 AUTO] ✅ Permisos concedidos - modo Silent funcionará correctamente');
      }
    } catch (e, stackTrace) {
      print('[POINT 2 AUTO] ❌ ERROR verificando permisos: $e');
      print('[POINT 2 AUTO] ❌ StackTrace: $stackTrace');
    }

    print('=== [POINT 2 AUTO] FIN VERIFICACIÓN ===');
    print('');
  }

  // Point 2: Modal informativo cuando los permisos están denegados
  Future<void> _showPermissionDeniedDialog(BuildContext dialogContext) async {
    print('[POINT 2 MODAL AUTO] 📦 Iniciando showDialog...');

    return showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        print(
            '[POINT 2 MODAL AUTO] 🎪 Builder ejecutado - Modal construyéndose');
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_off, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Permisos de Notificación',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Los permisos de notificación están desactivados.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Sin permisos de notificación, el modo Silent no funcionará correctamente.',
                ),
                SizedBox(height: 12),
                Text(
                  'Para activar los permisos:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('1. Toca "Permitir"'),
                Text('2. Busca "Notificaciones" en la configuración'),
                Text('3. Activa las notificaciones para Zync'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('[POINT 2 MODAL AUTO] 🔴 Usuario presionó botón CERRAR');
                Navigator.of(context).pop();
                print(
                    '[POINT 2 MODAL AUTO] 🔴 Modal cerrado - Usuario NO activó permisos');
              },
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                print(
                    '[POINT 2 MODAL AUTO] 🟢 Usuario presionó botón PERMITIR');
                Navigator.of(context).pop();
                print(
                    '[POINT 2 MODAL AUTO] 🔧 Abriendo configuración del sistema...');

                try {
                  await AppSettings.openAppSettings(
                      type: AppSettingsType.notification);
                  print(
                      '[POINT 2 MODAL AUTO] ✅ Configuración de notificaciones abierta exitosamente');
                } catch (e) {
                  print(
                      '[POINT 2 MODAL AUTO] ❌ Error abriendo configuración: $e');
                }
              },
              icon: const Icon(Icons.settings),
              label: const Text('Permitir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Limpia la funcionalidad silenciosa cuando no hay usuario autenticado
  /// Point 21 FASE 1: Limpiar cache y listeners, PERO NO desactivar notificación
  /// La notificación permanece activa hasta logout MANUAL desde Settings
  void _cleanupSilentFunctionalityIfNeeded() {
    // Point 21: Limpiar cache INMEDIATAMENTE (síncrono) para evitar pantalla transitoria
    // Esto previene que al reabrir la app se lea cache viejo y muestre HomePage momentáneamente
    SessionCacheService.clearSession().then((_) {
      print('🛡️ [AuthWrapper] Cache limpiado INMEDIATAMENTE');
    }).catchError((e) {
      print('⚠️ [AuthWrapper] Error limpiando cache: $e');
    });

    // Ejecutar resto de limpieza en background para NO bloquear la UI
    Future.microtask(() async {
      try {
        print('🔴 [AuthWrapper] Limpiando listeners y cache en background...');

        // Point 21 FASE 1: NO llamar deactivateAfterLogout() aquí
        // La notificación debe permanecer hasta logout MANUAL desde Settings

        // Solo limpiar listeners y estado local
        await StatusService.disposeStatusListener();
        await AppBadgeService.clearBadge();

        print('🔴 [AuthWrapper] Listeners y cache limpiados exitosamente');
        print(
            '💡 [AuthWrapper] Notificación permanece activa (logout manual desde Settings)');
      } catch (e) {
        print('❌ [AuthWrapper] Error limpiando listeners: $e');
      }
    });
  }
}
