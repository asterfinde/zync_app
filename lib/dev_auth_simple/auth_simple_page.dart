import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthSimplePage extends StatefulWidget {
  const AuthSimplePage({super.key});

  @override
  State<AuthSimplePage> createState() => _AuthSimplePageState();
}

class _AuthSimplePageState extends State<AuthSimplePage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  String _message = '';
  bool _isLogin = true;

  Future<void> _register() async {
    setState(() { _message = 'Registrando...'; });
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
        setState(() { _message = 'Registro exitoso: $uid'; });
        _navigateToHome();
      } else {
        setState(() { _message = 'Error: UID nulo tras registro.'; });
      }
    } catch (e) {
      setState(() { _message = 'Error en registro: $e'; });
    }
  }

  Future<void> _login() async {
    setState(() { _message = 'Iniciando sesión...'; });
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      setState(() { _message = 'Login exitoso: ${userCredential.user?.uid}'; });
      _navigateToHome();
    } catch (e) {
      setState(() { _message = 'Error en login: $e'; });
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePageSimple()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth Simple')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (!_isLogin)
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: 'Nickname'),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLogin ? _login : _register,
                  child: Text(_isLogin ? 'Login' : 'Registrar'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() { _isLogin = !_isLogin; });
                  },
                  child: Text(_isLogin ? '¿No tienes cuenta? Regístrate' : '¿Ya tienes cuenta? Login'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(_message),
          ],
        ),
      ),
    );
  }
}

class HomePageSimple extends StatelessWidget {
  const HomePageSimple({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Simple')),
      body: const Center(child: Text('¡Bienvenido!')),
    );
  }
}
