import 'package:flutter/foundation.dart' as Flutter;
import 'package:flutter/material.dart';
// <-- IMPORTAR PARA FLUTTER.COMPUTE

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
         if (mounted) {
            setState(() {
              _statusMessage = 'Error en isolate';
            });
         }
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
      if (mounted) {
        setState(() {
          _statusMessage = 'Error al lanzar';
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

    // Muestra este Scaffold solo por unos milisegundos
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
