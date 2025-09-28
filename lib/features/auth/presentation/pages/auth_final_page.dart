import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/features/circle/presentation/pages/home_page.dart';

class AuthFinalPage extends StatefulWidget {
  const AuthFinalPage({Key? key}) : super(key: key);

  @override
  State<AuthFinalPage> createState() => _AuthFinalPageState();
}

class _AuthFinalPageState extends State<AuthFinalPage> {
  Future<void> _login() async {
    setState(() { _isLoading = true; _message = ''; });
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
      // Navega a la página principal si el login es exitoso
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _message = getAuthErrorMessage(e.code); });
    } catch (e) {
      setState(() { _message = 'Error inesperado. Intenta de nuevo.'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _register() async {
    setState(() { _isLoading = true; _message = ''; });
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Guarda el nickname en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'nickname': _nicknameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'uid': userCredential.user?.uid,
      });
      // Navega a la página principal
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _message = getAuthErrorMessage(e.code); });
    } catch (e) {
      setState(() { _message = 'Error inesperado. Intenta de nuevo.'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  String getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Usuario no encontrado.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'El correo ya está registrado.';
      case 'invalid-email':
        return 'Correo inválido.';
      case 'weak-password':
        return 'La contraseña es muy débil.';
      default:
        return 'Error de autenticación.';
    }
  }
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isPasswordObscured = true;
  bool _isLoading = false;
  bool _isFormValid = false;
  String _message = '';

  void _showResetPasswordModal() {
    final TextEditingController resetEmailController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  prefixIcon: Icon(Icons.alternate_email, color: Color(0xFF7EAEA0)),
                  filled: true,
                  fillColor: Color(0xFF171D1B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF7EAEA0), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Por favor ingresa un correo válido.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    try {
                      await _auth.sendPasswordResetEmail(email: email);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Se enviaron las instrucciones a tu correo.'),
                          backgroundColor: Color(0xFF7EAEA0),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No se pudo enviar el correo. Verifica el email.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
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
      final nicknameValid = nickname.length >= 3;
      final passwordValid = password.length >= 6 && password.length <= 10 && password.trim().isNotEmpty;
      if (_isLogin) {
        _isFormValid = emailValid && passwordValid;
      } else {
        _isFormValid = nicknameValid && emailValid && passwordValid;
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
                Text(
                  _isLogin ? 'Inicia sesión para continuar' : 'Completa los campos para registrarte',
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
                          hintText: 'Tu apodo público',
                          hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.person_outline, color: secondaryTextColor),
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
                    hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.alternate_email, color: secondaryTextColor),
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
                        _isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
                          colors: [accentColor.withOpacity(0.8), accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isFormValid && !_isLoading ? (_isLogin ? _login : _register) : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          backgroundColor: _isFormValid && !_isLoading
                              ? Colors.transparent
                              : const Color(0xFF171D1B), // Fondo desactivado
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
                                : const Color(0xFF7EAEA0), // Font desactivado
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
                            _isLogin ? '¿No tienes una cuenta? ' : '¿Ya tienes una cuenta? ',
                            style: TextStyle(color: secondaryTextColor),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() { _isLogin = !_isLogin; });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              overlayColor: accentColor.withOpacity(0.1),
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
                          onPressed: _showResetPasswordModal,
                          child: Text('¿Olvidaste tu contraseña?', style: TextStyle(color: accentColor)),
                        ),
                    ],
                  ),
                ),
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _message,
                      style: TextStyle(color: accentColor),
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

