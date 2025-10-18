import 'package:flutter/material.dart';

/// Splash screen optimizado que se muestra INMEDIATAMENTE
/// mientras se completan las inicializaciones en background
class OptimizedSplashScreen extends StatefulWidget {
  final Future<void> Function() onInitialize;
  final Widget child;

  const OptimizedSplashScreen({
    super.key,
    required this.onInitialize,
    required this.child,
  });

  @override
  State<OptimizedSplashScreen> createState() => _OptimizedSplashScreenState();
}

class _OptimizedSplashScreenState extends State<OptimizedSplashScreen> {
  bool _isReady = false;
  String _statusMessage = 'Iniciando...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Ejecutar inicialización en background
      await widget.onInitialize();
      
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      print('❌ [SplashScreen] Error durante inicialización: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Error al inicializar';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo o icono de la app
            const Icon(
              Icons.circle,
              size: 80,
              color: Color(0xFF1EE9A4),
            ),
            const SizedBox(height: 24),
            
            // Indicador de carga
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1EE9A4)),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Mensaje de estado
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
