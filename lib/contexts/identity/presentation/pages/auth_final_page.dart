// lib/features/auth/presentation/pages/auth_final_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../app/theme/design_tokens.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nunakin_app/features/circle/presentation/pages/home_page.dart';
import 'package:nunakin_app/core/services/secure_credential_service.dart';
import 'package:nunakin_app/core/widgets/nunakin_text_field.dart';
import 'package:nunakin_app/core/widgets/nk_app_header.dart';

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
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _nicknameFocusNode = FocusNode();
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
    _nicknameController.addListener(_updateFormValid);
    _emailController.addListener(_updateFormValid);
    _passwordController.addListener(_updateFormValid);
    _confirmPasswordController.addListener(_updateFormValid);
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_updateFormValid);
    _emailController.removeListener(_updateFormValid);
    _passwordController.removeListener(_updateFormValid);
    _confirmPasswordController.removeListener(_updateFormValid);
    _emailFocusNode.dispose();
    _nicknameFocusNode.dispose();
    super.dispose();
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
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      await SecureCredentialService.saveCredentials(
        email: email,
        password: _passwordController.text,
      );
      // Login exitoso — navegar a HomePage reemplazando la ruta actual.
      // Los servicios se inicializan desde AuthWrapper (sin duplicación).
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = getAuthErrorMessage(e.code, isLogin: true);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_message, style: TextStyle(color: Colors.white)),
            backgroundColor: NkColors.danger,
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
            backgroundColor: NkColors.danger,
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
      await SecureCredentialService.saveCredentials(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final nickname = _nicknameController.text.trim();
      await userCredential.user?.updateDisplayName(nickname);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .set({
        'nickname': nickname,
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'uid': userCredential.user?.uid,
      });
      await userCredential.user?.sendEmailVerification();
      // Registro exitoso — navegar a HomePage reemplazando la ruta actual.
      // Los servicios se inicializan desde AuthWrapper (sin duplicación).
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
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
            backgroundColor: NkColors.danger,
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
          return 'Correo o contraseña incorrectos. Verifica que te has registrado e intenta de nuevo.';
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


  // PROCESO ACTUAL: Solo Firebase Auth (comportamiento estándar)
  Future<bool> _sendPasswordResetEmail(String email) async {
    if (kDebugMode) {
      log('[PROCESO AUTH] Iniciando envío de correo de recuperación para email: $email',
          name: 'PasswordReset');
    }
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
      backgroundColor: NkColors.canvas,
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
                    style: TextStyle(color: NkColors.fgSub),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('field_reset_email'),
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: NkColors.fgSub),
                      prefixIcon:
                          Icon(Icons.alternate_email, color: NkColors.fgSub),
                      filled: true,
                      fillColor: Color(0xFF171D1B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: NkColors.mintSoft(0.4), width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: NkColors.fgSub, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(NkColors.fgSub),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('btn_send_reset'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NkColors.fgSub,
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

                          if (kDebugMode) {
                            log('\n[VALIDACIÓN] Email ingresado: "$email"',
                                name: 'PasswordReset');
                          }

                          // CASO 3: Validación de campo vacío
                          if (email.isEmpty) {
                            log('[VALIDACIÓN] ❌ Email vacío',
                                name: 'PasswordReset');
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text('Por favor ingresa un correo.',
                                    style: TextStyle(color: Colors.white)),
                                backgroundColor: NkColors.danger,
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
                          if (kDebugMode) {
                            log('[TREN EJECUCIÓN] Email a procesar: $email',
                                name: 'PasswordReset');
                          }
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
                                  backgroundColor: NkColors.danger,
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
    const accentColor = NkColors.mint;

    return Scaffold(
      backgroundColor: NkColors.canvas,
      body: Column(
        children: [
          const NkAppHeader(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isLogin ? 'Bienvenido' : 'Crea tu cuenta',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: NkColors.onDark,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                // Timestamp dinámico para verificar versión
                Text(
                  'v$_currentTime',
                  style: TextStyle(
                    fontSize: 10,
                    color: NkColors.fgHint,
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
                    color: NkColors.fgMuted,
                  ),
                ),
                const SizedBox(height: 40),
                if (!_isLogin)
                  Column(
                    children: [
                      NunaKinTextField(
                        key: const Key('field_nickname'),
                        label: 'Nickname',
                        placeholder: 'Tu apodo público (mínimo 1 caracter)',
                        icon: Icons.person_outline,
                        controller: _nicknameController,
                        focusNode: _nicknameFocusNode,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                NunaKinTextField(
                  key: const Key('field_email'),
                  label: 'Email',
                  placeholder: 'tu.email@ejemplo.com',
                  icon: Icons.alternate_email,
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                NunaKinTextField(
                  key: const Key('field_password'),
                  label: 'Contraseña',
                  placeholder: '',
                  icon: Icons.lock_outline,
                  controller: _passwordController,
                  obscureText: _isPasswordObscured,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: NkColors.fgSub,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordObscured = !_isPasswordObscured;
                      });
                    },
                  ),
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  NunaKinTextField(
                    key: const Key('field_confirm_password'),
                    label: 'Confirmar Contraseña',
                    placeholder: '',
                    icon: Icons.lock_outline,
                    controller: _confirmPasswordController,
                    obscureText: _isConfirmPasswordObscured,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordObscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: NkColors.fgSub,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
                        });
                      },
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
                        key: const Key('btn_auth'),
                        onPressed: _isFormValid && !_isLoading
                            ? (_isLogin ? _login : _register)
                            : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          backgroundColor: _isFormValid && !_isLoading
                              ? Colors.transparent
                              : NkColors.canvas,
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
                                : NkColors.fgSub,
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
                            style: TextStyle(color: NkColors.fgMuted),
                          ),
                          TextButton(
                            key: const Key('btn_toggle_mode'),
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!_isLogin) {
                                  _nicknameFocusNode.requestFocus();
                                } else {
                                  _emailFocusNode.requestFocus();
                                }
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
                          key: const Key('btn_forgot_password'),
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
          ),
        ],
      ),
    );
  }
}
