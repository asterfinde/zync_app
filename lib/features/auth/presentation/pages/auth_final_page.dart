import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
// import 'package:zync_app/features/circle/presentation/pages/home_page.dart';

class AuthFinalPage extends StatefulWidget {
  const AuthFinalPage({Key? key}) : super(key: key);

  @override
  State<AuthFinalPage> createState() => _AuthFinalPageState();
}

class _AuthFinalPageState extends State<AuthFinalPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  String _message = '';
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  Future<void> _register() async {
    setState(() { _isLoading = true; _message = ''; });
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = userCredential.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': _emailController.text.trim(),
          'nickname': _nicknameController.text.trim(),
        });
        setState(() { _message = 'Registro exitoso'; });
        _navigateToHome();
      } else {
        setState(() { _message = 'Error: UID nulo tras registro.'; });
      }
    } catch (e) {
      setState(() { _message = 'Error en registro: $e'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _message = ''; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      setState(() { _message = 'Login exitoso'; });
      _navigateToHome();
    } catch (e) {
      setState(() { _message = 'Error en login: $e'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
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
                        onPressed: _isLogin ? _login : _register,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? '¿No tienes una cuenta?' : '¿Ya tienes una cuenta?',
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


