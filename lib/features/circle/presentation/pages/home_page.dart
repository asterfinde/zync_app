import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../services/circle_service.dart';
import '../widgets/in_circle_view.dart';
import '../widgets/no_circle_view.dart';
import '../widgets/pending_request_view.dart';
import '../../../../core/services/session_cache_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = CircleService();
  bool _isEmailVerified = true;

  @override
  void initState() {
    super.initState();
    _saveSessionProactively();
    _checkEmailVerification();
  }

  void _saveSessionProactively() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      SessionCacheService.saveSession(
        userId: user.uid,
        email: user.email ?? '',
      ).then((_) {
        print('✅ [HomePage] Sesión guardada proactivamente');
      }).catchError((e) {
        print('❌ [HomePage] Error guardando sesión: $e');
      });
    }
  }

  Future<void> _checkEmailVerification() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (mounted) {
      setState(() {
        _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? true;
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correo de verificación reenviado.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo reenviar. Intenta más tarde.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEmailVerificationBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF2A1F00),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Verifica tu correo para activar todas las funciones',
              style: TextStyle(color: Colors.amber, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _checkEmailVerification,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Ya lo hice', style: TextStyle(color: Colors.amber, fontSize: 12)),
          ),
          TextButton(
            onPressed: _resendVerificationEmail,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Reenviar', style: TextStyle(color: Colors.amber, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          if (!_isEmailVerified) _buildEmailVerificationBanner(),
          Expanded(child: StreamBuilder<UserCircleState>(
        stream: _service.getUserCircleStream(),
        builder: (context, snapshot) {
          // Mostrar loading solo en la primera carga
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando...', style: TextStyle(color: Colors.white)),
                ],
              ),
            );
          }

          final state = snapshot.data;

          if (state is UserInCircle) {
            return InCircleView(circle: state.circle);
          } else if (state is UserPendingRequest) {
            return PendingRequestView(pendingCircleId: state.pendingCircleId);
          } else {
            return const NoCircleView();
          }
        },
      )),
        ],
      ),
    );
  }
}
