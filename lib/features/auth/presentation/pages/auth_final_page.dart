// lib/features/auth/presentation/pages/auth_final_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
import 'package:zync_app/core/services/silent_functionality_coordinator.dart';
import 'package:zync_app/core/services/status_service.dart';
import 'package:zync_app/notifications/notification_service.dart'; // Point 2
import 'package:app_settings/app_settings.dart'; // Point 2
import 'package:zync_app/services/circle_service.dart';

class AuthFinalPage extends StatefulWidget {
  const AuthFinalPage({super.key});

  @override
  State<AuthFinalPage> createState() => _AuthFinalPageState();
}

class _AuthFinalPageState extends State<AuthFinalPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isConfirmPasswordObscured = true;
  bool _isLogin = true;
  bool _isPasswordObscured = true;
  bool _isLoading = false;
  bool _isFormValid = false;
  String _message = '';
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _startTimeUpdater();
  }

  void _startTimeUpdater() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _updateTime();
        return true;
      }
      return false;
    });
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateTime.now().toString().substring(11, 19);
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    final email = _emailController.text.trim();
    final emailValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailValid) {
      setState(() {
        _isLoading = false;
        _message = 'Por favor ingresa un correo válido.';
      });
      return;
    }
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      if (userCredential.user != null) {
        if (mounted) {
          // Activar funcionalidad silenciosa después del login exitoso
          print(
              '🟢 [LOGIN] Login exitoso, activando funcionalidad silenciosa...');
          await SilentFunctionalityCoordinator.activateAfterLogin(context);
          print('🟢 [LOGIN] activateAfterLogin completado');

          // Inicializar listener de estados para badge
          print('🟢 [LOGIN] Inicializando status listener para badge...');
          try {
            await StatusService.initializeStatusListener();
            print('🟢 [LOGIN] Status listener inicializado exitosamente');
          } catch (e) {
            print('❌ [LOGIN] Error inicializando status listener: $e');
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (newContext) {
              // Point 2: Verificar permisos DESPUÉS de navegar
              Future.delayed(const Duration(milliseconds: 300), () {
                print(
                    '🔔 [POINT 2] Verificando permisos después de navegación (LOGIN)...');
                print('🔔 [POINT 2] Context mounted: ${newContext.mounted}');
                if (newContext.mounted) {
                  _checkNotificationPermissionsInContext(newContext);
                } else {
                  print(
                      '❌ [POINT 2] Context NO mounted - no se puede mostrar modal');
                }
              });
              return HomePage();
            }),
          );
        }
      } else {
        setState(() {
          _message = 'Usuario no encontrado.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = getAuthErrorMessage(e.code, isLogin: true);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_message, style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _message = 'Error inesperado. Intenta de nuevo.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_message, style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .set({
        'nickname': _nicknameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'uid': userCredential.user?.uid,
      });
      await userCredential.user?.sendEmailVerification();
      if (mounted) {
        // Activar funcionalidad silenciosa después del registro exitoso
        print(
            '🟢 [REGISTER] Registro exitoso, activando funcionalidad silenciosa...');
        await SilentFunctionalityCoordinator.activateAfterLogin(context);
        print('🟢 [REGISTER] activateAfterLogin completado');

        // Inicializar listener de estados para badge
        print('🟢 [REGISTER] Inicializando status listener para badge...');
        try {
          await StatusService.initializeStatusListener();
          print('🟢 [REGISTER] Status listener inicializado exitosamente');
        } catch (e) {
          print('❌ [REGISTER] Error inicializando status listener: $e');
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (newContext) {
            // Point 2: Verificar permisos DESPUÉS de navegar
            Future.delayed(const Duration(milliseconds: 300), () {
              print(
                  '🔔 [POINT 2] Verificando permisos después de navegación (REGISTER)...');
              print('🔔 [POINT 2] Context mounted: ${newContext.mounted}');
              if (newContext.mounted) {
                _checkNotificationPermissionsInContext(newContext);
              } else {
                print(
                    '❌ [POINT 2] Context NO mounted - no se puede mostrar modal');
              }
            });
            return HomePage();
          }),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = getAuthErrorMessage(e.code, isLogin: false);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_message, style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _message = 'Error inesperado. Intenta de nuevo.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String getAuthErrorMessage(String code, {bool isLogin = true}) {
    if (isLogin) {
      switch (code) {
        case 'user-not-found':
          return 'No encontramos una cuenta con ese correo.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'La contraseña es incorrecta. Verifica e intenta de nuevo.';
        case 'invalid-email':
          return 'El formato del correo no es válido.';
        case 'user-disabled':
          return 'Esta cuenta ha sido deshabilitada.';
        case 'too-many-requests':
          return 'Demasiados intentos fallidos. Espera unos minutos.';
        default:
          return 'Error inesperado de autenticación.';
      }
    } else {
      switch (code) {
        case 'email-already-in-use':
          return 'Este correo ya tiene una cuenta registrada. Inicia sesión.';
        case 'weak-password':
          return 'Contraseña muy débil. Usa al menos 6 caracteres.';
        case 'invalid-email':
          return 'El formato del correo no es válido.';
        default:
          return 'Error inesperado de autenticación.';
      }
    }
  }

  // Point 2: Verificar permisos de notificación después del login/registro
  Future<void> _checkNotificationPermissionsInContext(
      BuildContext checkContext) async {
    print('');
    print('=== [POINT 2] INICIANDO VERIFICACIÓN DE PERMISOS ===');
    print('[POINT 2] Context mounted: ${checkContext.mounted}');

    try {
      // VERIFICAR PRIMERO SI EL USUARIO PERTENECE A UN CÍRCULO
      print('[POINT 2] 🔍 Verificando si el usuario pertenece a un círculo...');
      final circleService = CircleService();
      final userCircle = await circleService.getUserCircle();

      if (userCircle == null) {
        print('[POINT 2] ⚠️ Usuario NO pertenece a un círculo');
        print('[POINT 2] ⚠️ NO se verificarán permisos ni se mostrará modal');
        print('[POINT 2] 💡 El modal aparecerá cuando se una/cree un círculo');
        return;
      }

      print('[POINT 2] ✅ Usuario pertenece al círculo: ${userCircle.name}');
      print('[POINT 2] Llamando a NotificationService.hasPermission()...');
      final hasPermission = await NotificationService.hasPermission();

      print('[POINT 2] 🔍 Resultado hasPermission: $hasPermission');
      print('[POINT 2] Context aún mounted: ${checkContext.mounted}');

      if (!hasPermission) {
        print('[POINT 2] ⚠️ Permisos DENEGADOS - Intentando mostrar modal...');

        if (checkContext.mounted) {
          print('[POINT 2] ✅ Context mounted - Mostrando modal informativo');
          await _showPermissionDeniedDialogInContext(checkContext);
          print('[POINT 2] ✅ Modal mostrado exitosamente');
        } else {
          print('[POINT 2] ❌ Context NO mounted - No se puede mostrar modal');
        }
      } else {
        print(
            '[POINT 2] ✅ Permisos concedidos - modo Silent funcionará correctamente');
      }
    } catch (e, stackTrace) {
      print('[POINT 2] ❌ ERROR verificando permisos: $e');
      print('[POINT 2] ❌ StackTrace: $stackTrace');
    }

    print('=== [POINT 2] FIN VERIFICACIÓN DE PERMISOS ===');
    print('');
  }

  // Point 2: Modal informativo cuando los permisos están denegados
  Future<void> _showPermissionDeniedDialogInContext(
      BuildContext dialogContext) async {
    print('[POINT 2 MODAL] 📦 Iniciando showDialog...');
    print('[POINT 2 MODAL] Context: ${dialogContext.mounted}');

    return showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        print('[POINT 2 MODAL] 🎪 Builder ejecutado - Modal construyéndose');
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
                print('[POINT 2 MODAL] 🔴 Usuario presionó botón CERRAR');
                Navigator.of(dialogContext).pop();
                print(
                    '[POINT 2 MODAL] 🔴 Modal cerrado - Usuario NO activó permisos');
              },
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                print('[POINT 2 MODAL] 🟢 Usuario presionó botón PERMITIR');
                Navigator.of(dialogContext).pop();
                print(
                    '[POINT 2 MODAL] 🔧 Abriendo configuración del sistema...');

                try {
                  await AppSettings.openAppSettings(
                      type: AppSettingsType.notification);
                  print(
                      '[POINT 2 MODAL] ✅ Configuración de notificaciones abierta exitosamente');
                } catch (e) {
                  print('[POINT 2 MODAL] ❌ Error abriendo configuración: $e');
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

  // PROCESO ACTUAL: Solo Firebase Auth (comportamiento estándar)
  Future<bool> _sendPasswordResetEmail(String email) async {
    log('[PROCESO AUTH] Iniciando envío de correo de recuperación para email: $email',
        name: 'PasswordReset');
    log('[PROCESO AUTH] ⚠️ NOTA: Firebase Auth no valida existencia por seguridad',
        name: 'PasswordReset');

    try {
      await _auth.sendPasswordResetEmail(email: email);
      log('[PROCESO AUTH] ✅ Correo procesado (enviado si el usuario existe)',
          name: 'PasswordReset');
      return true;
    } on FirebaseAuthException catch (e) {
      log('[PROCESO AUTH] ❌ FirebaseAuthException: ${e.code}',
          name: 'PasswordReset', error: e);

      switch (e.code) {
        case 'invalid-email':
          throw Exception('invalid_email');
        case 'network-request-failed':
        case 'too-many-requests':
          throw Exception('network_error');
        default:
          throw Exception('auth_error_${e.code}');
      }
    } catch (e) {
      log('[PROCESO AUTH] ❌ Error general: $e',
          name: 'PasswordReset', error: e);
      throw Exception('connection_error');
    }
  }

  void _showResetPasswordModal(
      BuildContext rootContext, void Function(String, Color) onFeedback) {
    final TextEditingController resetEmailController = TextEditingController();
    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Recuperar contraseña',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ingresa tu correo electrónico y te enviaremos instrucciones para recuperar tu contraseña.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF7EAEA0)),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Color(0xFF7EAEA0)),
                      prefixIcon:
                          Icon(Icons.alternate_email, color: Color(0xFF7EAEA0)),
                      filled: true,
                      fillColor: Color(0xFF171D1B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Color(0xFF7EAEA0), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF7EAEA0)),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF7EAEA0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Enviar instrucciones',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: () async {
                          final email = resetEmailController.text.trim();

                          log('\n[VALIDACIÓN] Email ingresado: "$email"',
                              name: 'PasswordReset');

                          // CASO 3: Validación de campo vacío
                          if (email.isEmpty) {
                            log('[VALIDACIÓN] ❌ Email vacío',
                                name: 'PasswordReset');
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text('Por favor ingresa un correo.',
                                    style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // CASO 3: Validación de formato de email
                          final emailValid =
                              RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email);
                          log('[VALIDACIÓN] Formato de email válido: $emailValid',
                              name: 'PasswordReset');
                          if (!emailValid) {
                            log('[VALIDACIÓN] ❌ Formato de email inválido',
                                name: 'PasswordReset');
                            return;
                          }

                          log('[VALIDACIÓN] ✅ Todas las validaciones pasaron. Iniciando loading...',
                              name: 'PasswordReset');
                          setModalState(() => isLoading = true);

                          // PROCESO ÚNICO: Solo Firebase Auth
                          log('\n[TREN EJECUCIÓN] =================================',
                              name: 'PasswordReset');
                          log('[TREN EJECUCIÓN] Iniciando recuperación de contraseña',
                              name: 'PasswordReset');
                          log('[TREN EJECUCIÓN] Email a procesar: $email',
                              name: 'PasswordReset');
                          log('[TREN EJECUCIÓN] Usando solo Firebase Auth (sin Firestore)',
                              name: 'PasswordReset');
                          log('[TREN EJECUCIÓN] =================================\n',
                              name: 'PasswordReset');

                          try {
                            // PROCESO ÚNICO: Firebase Auth maneja existencia y envío
                            log('[TREN EJECUCIÓN] Ejecutando proceso de envío...',
                                name: 'PasswordReset');
                            bool success = await _sendPasswordResetEmail(email);
                            log('[TREN EJECUCIÓN] Resultado del proceso: $success',
                                name: 'PasswordReset');

                            if (success) {
                              // ÉXITO COMPLETO
                              log('[TREN EJECUCIÓN] 🎉 ÉXITO: Correo enviado correctamente',
                                  name: 'PasswordReset');
                              log('[TREN EJECUCIÓN] Mostrando SnackBar verde de éxito',
                                  name: 'PasswordReset');
                              // ignore: use_build_context_synchronously
                              Navigator.of(modalContext).pop();
                              if (mounted) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Hemos enviado las instrucciones. Si no las recibes, verifica que el correo esté registrado.',
                                        style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            log('\n[TREN EJECUCIÓN] ❌ ERROR CAPTURADO:',
                                name: 'PasswordReset', error: e);
                            log('[TREN EJECUCIÓN] Error completo: $e',
                                name: 'PasswordReset');
                            log('[TREN EJECUCIÓN] Tipo de error: ${e.runtimeType}',
                                name: 'PasswordReset');
                            log('[TREN EJECUCIÓN] String del error: ${e.toString()}',
                                name: 'PasswordReset');

                            Navigator.of(modalContext).pop();
                            String errorMessage;

                            // Manejo de errores simplificado (solo Firebase Auth)
                            if (e.toString().contains('user_not_found')) {
                              log('[TREN EJECUCIÓN] Clasificado como: USUARIO NO EXISTE',
                                  name: 'PasswordReset');
                              errorMessage =
                                  'No existe ninguna cuenta con ese correo.';
                            } else if (e.toString().contains('invalid_email')) {
                              log('[TREN EJECUCIÓN] Clasificado como: EMAIL INVÁLIDO',
                                  name: 'PasswordReset');
                              errorMessage =
                                  'Por favor ingresa un correo válido.';
                            } else if (e.toString().contains('network_error')) {
                              log('[TREN EJECUCIÓN] Clasificado como: ERROR DE RED',
                                  name: 'PasswordReset');
                              errorMessage =
                                  'No hay conexión de internet. Intenta de nuevo.';
                            } else if (e
                                .toString()
                                .contains('connection_error')) {
                              log('[TREN EJECUCIÓN] Clasificado como: ERROR DE CONEXIÓN',
                                  name: 'PasswordReset');
                              errorMessage =
                                  'Error de conexión. Intenta de nuevo.';
                            } else if (e.toString().contains('auth_error_')) {
                              log('[TREN EJECUCIÓN] Clasificado como: ERROR DE AUTENTICACIÓN',
                                  name: 'PasswordReset');
                              errorMessage =
                                  'Error en el sistema de autenticación. Intenta de nuevo.';
                            } else {
                              log('[TREN EJECUCIÓN] Clasificado como: ERROR INESPERADO',
                                  name: 'PasswordReset');
                              errorMessage =
                                  'Error inesperado. Intenta de nuevo.';
                            }

                            log('[TREN EJECUCIÓN] Mensaje final al usuario: $errorMessage',
                                name: 'PasswordReset');
                            log('[TREN EJECUCIÓN] =================================\n',
                                name: 'PasswordReset');

                            if (mounted) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage,
                                      style: TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            log('[TREN EJECUCIÓN] Finalizando proceso en bloque finally',
                                name: 'PasswordReset');
                            if (mounted) {
                              log('[TREN EJECUCIÓN] Widget aún montado, desactivando loading',
                                  name: 'PasswordReset');
                              setModalState(() => isLoading = false);
                            } else {
                              log('[TREN EJECUCIÓN] ⚠️ Widget ya no está montado',
                                  name: 'PasswordReset');
                            }
                            log('[TREN EJECUCIÓN] Proceso completado\n',
                                name: 'PasswordReset');
                          }
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateFormValid() {
    setState(() {
      final email = _emailController.text.trim();
      final emailValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
      final nickname = _nicknameController.text.trim();
      final password = _passwordController.text;
      final nicknameValid = nickname.isNotEmpty;
      final passwordValid = password.length >= 6 &&
          password.trim().isNotEmpty;
      if (_isLogin) {
        _isFormValid = emailValid && passwordValid;
      } else {
        final confirmPassword = _confirmPasswordController.text;
        final confirmPasswordValid = confirmPassword == _passwordController.text && confirmPassword.isNotEmpty;
        _isFormValid = nicknameValid && emailValid && passwordValid && confirmPasswordValid;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Colors.tealAccent.shade400;
    final primaryTextColor = Colors.white;
    final secondaryTextColor = Colors.grey.shade400;
    final inputFillColor = Colors.black26;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zync'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isLogin ? 'Bienvenido' : 'Crea tu Cuenta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Timestamp dinámico para verificar versión
                Text(
                  'v$_currentTime',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Inicia sesión para continuar'
                      : 'Completa los campos para registrarte',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 40),
                if (!_isLogin)
                  Column(
                    children: [
                      TextField(
                        controller: _nicknameController,
                        onChanged: (_) => _updateFormValid(),
                        style: TextStyle(color: primaryTextColor),
                        decoration: InputDecoration(
                          labelText: 'Nickname',
                          labelStyle: TextStyle(color: secondaryTextColor),
                          hintText: 'Tu apodo público (mínimo 1 caracter)',
                          hintStyle: TextStyle(
                              color: secondaryTextColor.withValues(alpha: 0.5)),
                          prefixIcon: Icon(Icons.person_outline,
                              color: secondaryTextColor),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                TextField(
                  controller: _emailController,
                  onChanged: (_) => _updateFormValid(),
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    hintText: 'tu.email@ejemplo.com',
                    hintStyle: TextStyle(
                        color: secondaryTextColor.withValues(alpha: 0.5)),
                    prefixIcon:
                        Icon(Icons.alternate_email, color: secondaryTextColor),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  onChanged: (_) => _updateFormValid(),
                  obscureText: _isPasswordObscured,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon:
                        Icon(Icons.lock_outline, color: secondaryTextColor),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordObscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: secondaryTextColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordObscured = !_isPasswordObscured;
                        });
                      },
                    ),
                  ),
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    onChanged: (_) => _updateFormValid(),
                    obscureText: _isConfirmPasswordObscured,
                    style: TextStyle(color: primaryTextColor),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Contraseña',
                      labelStyle: TextStyle(color: secondaryTextColor),
                      prefixIcon: Icon(Icons.lock_outline, color: secondaryTextColor),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accentColor, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordObscured
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: secondaryTextColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
                          });
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_isLoading)
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                if (!_isLoading)
                  Opacity(
                    opacity: 1.0,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.8),
                            accentColor
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isFormValid && !_isLoading
                            ? (_isLogin ? _login : _register)
                            : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          backgroundColor: _isFormValid && !_isLoading
                              ? Colors.transparent
                              : const Color(0xFF171D1B),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _isFormValid && !_isLoading
                                ? Colors.black
                                : const Color(0xFF7EAEA0),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? '¿No tienes una cuenta? '
                                : '¿Ya tienes una cuenta? ',
                            style: TextStyle(color: secondaryTextColor),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              overlayColor: accentColor.withValues(alpha: 0.1),
                            ),
                            child: Text(
                              _isLogin ? 'Regístrate' : 'Inicia Sesión',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isLogin)
                        TextButton(
                          onPressed: () {
                            _showResetPasswordModal(
                              context,
                              (message, color) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message,
                                        style: TextStyle(color: Colors.white)),
                                    backgroundColor: color,
                                  ),
                                );
                              },
                            );
                          },
                          child: Text('¿Olvidaste tu contraseña?',
                              style: TextStyle(color: accentColor)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
