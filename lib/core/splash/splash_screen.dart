import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../app/theme/design_tokens.dart';

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
    _entranceController = AnimationController(vsync: this, duration: const Duration(seconds: 1));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeIn));

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

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
      // Mostrar splash animado por 4 segundos (breathing effect)
      final splashDuration = Future.delayed(const Duration(seconds: 4));

      // Ejecutar inicialización en background (si hay algo que hacer)
      final initFuture = widget.onInitialize();

      // Esperar a que ambos terminen (lo que tarde más)
      await Future.wait([splashDuration, initFuture]);

      // Marcar como listo para mostrar AuthWrapper
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      print('❌ [SplashScreen] Error durante inicialización: $e');
      // Mostrar AuthWrapper aunque haya error
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
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

    // Muestra el splash animado con breathing effect (2 segundos)
    return Scaffold(
      backgroundColor: NkColors.canvas,
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
                        child: CustomPaint(painter: ZyncLogoPainter(color: NkColors.mint)),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "ZYNC",
                        style: TextStyle(
                          color: NkColors.mint,
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
                    style: const TextStyle(color: NkColors.fgHint, fontSize: 14),
                    children: const [
                      TextSpan(
                        text: "AI",
                        style: TextStyle(fontWeight: FontWeight.w900, color: NkColors.fgMuted),
                      ),
                      TextSpan(text: "nfers"),
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
