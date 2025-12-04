import 'package:flutter/foundation.dart' as Flutter;
import 'package:flutter/material.dart';
import 'dart:math' as math;

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

// --- INICIO DE LA MODIFICACIÓN ---
// Función "top-level" o "static" requerida para Flutter.compute
// Esta es la función que se ejecutará en el nuevo isolate.
Future<void> _runInitialization(Future<void> Function() onInitialize) async {
  // Esta función ahora se ejecuta en un Isolate separado,
  // sin bloquear el hilo de la UI.
  print('ISOLATE: [${DateTime.now()}] Iniciando inicialización en background isolate...');
  await onInitialize();
  print('ISOLATE: [${DateTime.now()}] Background isolate terminó inicialización.');
}
// --- FIN DE LA MODIFICACIÓN ---

class _OptimizedSplashScreenState extends State<OptimizedSplashScreen> with TickerProviderStateMixin {
  bool _isReady = false;

  late AnimationController _entranceController;
  late AnimationController _pulseController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Configurar animaciones
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
    _pulseController.repeat(reverse: true);

    _initialize();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // --- INICIO DE LA MODIFICACIÓN ---
      //
      // PROBLEMA ANTERIOR: widget.onInitialize() (los 1.8s de carga)
      // se ejecutaba en el main isolate (UI thread), compitiendo
      // con el build() de HomePage y causando 207 frames skippeados.
      //
      // SOLUCIÓN: Mover TODA la inicialización a un isolate separado
      // usando Flutter.compute.

      // 1. Lanzamos la inicialización en un isolate de background.
      //    Esto NO bloquea el UI thread.
      Flutter.compute(_runInitialization, widget.onInitialize).catchError((e) {
        print('❌ [SplashScreen] Error fatal en background isolate: $e');
      });

      // 2. Inmediatamente (mientras el isolate trabaja) marcamos como listo
      //    para mostrar el AuthWrapper.
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
      // --- FIN DE LA MODIFICACIÓN ---
    } catch (e) {
      print('❌ [SplashScreen] Error durante el lanzamiento de la inicialización: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      // Muestra el AuthWrapper inmediatamente (<100ms)
      // El AuthWrapper se encargará de esperar (en background)
      // a que el isolate de _runInitialization termine.
      return widget.child;
    }

    const zyncBrandColor = Color(0xFF1CE8A1);

    // Muestra el splash animado mientras inicializa
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              FadeTransition(
                opacity: _opacityAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CustomPaint(
                          painter: ZyncLogoPainter(color: zyncBrandColor),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "ZYNC",
                        style: TextStyle(
                          color: zyncBrandColor,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          fontFamily: 'Segoe UI',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: Text.rich(
                  TextSpan(
                    text: "powered by dat",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(
                        text: "AI",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[300],
                        ),
                      ),
                      const TextSpan(text: "nfers"),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter para el logo ZYNC (estrella de 5 puntas con nodos)
class ZyncLogoPainter extends CustomPainter {
  final Color color;

  ZyncLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Proporciones ajustadas
    final strokeWidth = size.width * 0.05;
    final radius = size.width * 0.35;
    final outerNodeRadius = size.width * 0.085;
    final centerNodeRadius = outerNodeRadius * 1.8;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Brazos (5 líneas desde el centro)
    for (int i = 0; i < 5; i++) {
      final angle = (2 * math.pi * i / 5) - (math.pi / 2);
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      canvas.drawLine(Offset(cx, cy), Offset(x, y), linePaint);
    }

    // Nodo centro
    canvas.drawCircle(Offset(cx, cy), centerNodeRadius, paint);

    // Nodos externos
    for (int i = 0; i < 5; i++) {
      final angle = (2 * math.pi * i / 5) - (math.pi / 2);
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), outerNodeRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ZyncLogoPainter && oldDelegate.color != color;
  }
}

/////////////////////////////////////////////

// import 'package:flutter/material.dart';

// /// Splash screen optimizado que se muestra INMEDIATAMENTE
// /// mientras se completan las inicializaciones en background
// class OptimizedSplashScreen extends StatefulWidget {
//   final Future<void> Function() onInitialize;
//   final Widget child;

//   const OptimizedSplashScreen({
//     super.key,
//     required this.onInitialize,
//     required this.child,
//   });

//   @override
//   State<OptimizedSplashScreen> createState() => _OptimizedSplashScreenState();
// }

// class _OptimizedSplashScreenState extends State<OptimizedSplashScreen> {
//   bool _isReady = false;
//   String _statusMessage = 'Iniciando...';

//   @override
//   void initState() {
//     super.initState();
//     _initialize();
//   }

//   Future<void> _initialize() async {
//     try {
//       // Ejecutar inicialización en background
//       await widget.onInitialize();
      
//       if (mounted) {
//         setState(() {
//           _isReady = true;
//         });
//       }
//     } catch (e) {
//       print('❌ [SplashScreen] Error durante inicialización: $e');
//       if (mounted) {
//         setState(() {
//           _statusMessage = 'Error al inicializar';
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isReady) {
//       return widget.child;
//     }

//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // Logo o icono de la app
//             const Icon(
//               Icons.circle,
//               size: 80,
//               color: Color(0xFF1EE9A4),
//             ),
//             const SizedBox(height: 24),
            
//             // Indicador de carga
//             const SizedBox(
//               width: 40,
//               height: 40,
//               child: CircularProgressIndicator(
//                 strokeWidth: 3,
//                 valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1EE9A4)),
//               ),
//             ),
            
//             const SizedBox(height: 16),
            
//             // Mensaje de estado
//             Text(
//               _statusMessage,
//               style: const TextStyle(
//                 color: Colors.white70,
//                 fontSize: 14,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
