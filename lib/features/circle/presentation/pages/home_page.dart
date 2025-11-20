import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../services/circle_service.dart';
import '../widgets/in_circle_view.dart';
import '../widgets/no_circle_view.dart';
import '../../../../core/services/session_cache_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = CircleService();

  @override
  void initState() {
    super.initState();
    // FASE 2B: Guardar sesión PROACTIVAMENTE al llegar a HomePage
    _saveSessionProactively();
  }
  
  /// Guardar sesión inmediatamente (no esperar a minimizar)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<Circle?>(
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

          final circle = snapshot.data;
          
          if (circle != null) {
            // Usuario está en un círculo - mostrar InCircleView
            return InCircleView(circle: circle);
          } else {
            // Usuario NO está en círculo - mostrar NoCircleView
            return const NoCircleView();
          }
        },
      ),
    );
  }
}
