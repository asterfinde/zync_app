// performance_tracker.dart
// Sistema completo para medir qué causa demoras en maximización

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Tracker de rendimiento para identificar cuellos de botella
class PerformanceTracker {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, Duration> _measurements = {};
  static DateTime? _appPausedAt;
  static DateTime? _appResumedAt;

  /// Iniciar medición de una operación
  static void start(String operation) {
    _startTimes[operation] = DateTime.now();
    if (kDebugMode) {
      print('⏱️ [START] $operation');
    }
  }

  /// Finalizar medición de una operación
  static void end(String operation) {
    if (_startTimes.containsKey(operation)) {
      final duration = DateTime.now().difference(_startTimes[operation]!);
      _measurements[operation] = duration;
      
      // Alertar si toma más de 300ms
      final color = duration.inMilliseconds > 300 ? '🔴' : '✅';
      if (kDebugMode) {
        print('$color [END] $operation - ${duration.inMilliseconds}ms');
      }
      
      _startTimes.remove(operation);
    }
  }

  /// Registrar cuando app se minimiza
  static void onAppPaused() {
    _appPausedAt = DateTime.now();
    if (kDebugMode) {
      print('⏸️ [APP] Minimizada a las $_appPausedAt');
    }
  }

  /// Registrar cuando app se maximiza
  static void onAppResumed() {
    _appResumedAt = DateTime.now();
    if (_appPausedAt != null) {
      final pausedDuration = _appResumedAt!.difference(_appPausedAt!);
      if (kDebugMode) {
        print('▶️ [APP] Restaurada después de ${pausedDuration.inSeconds}s');
      }
    }
  }

  /// Obtener reporte completo
  static String getReport() {
    final buffer = StringBuffer();
    buffer.writeln('\n📊 === REPORTE DE RENDIMIENTO ===\n');
    
    // Ordenar por duración (más lento primero)
    final sorted = _measurements.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final entry in sorted) {
      final ms = entry.value.inMilliseconds;
      final icon = ms > 500 ? '🔴' : (ms > 200 ? '🟡' : '🟢');
      buffer.writeln('$icon ${entry.key}: ${ms}ms');
    }
    
    buffer.writeln('\n=================================\n');
    return buffer.toString();
  }

  /// Limpiar mediciones
  static void clear() {
    _measurements.clear();
    _startTimes.clear();
  }
}

/// Widget wrapper para medir construcción
class MeasuredWidget extends StatelessWidget {
  final String name;
  final Widget child;

  const MeasuredWidget({
    super.key,
    required this.name,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    PerformanceTracker.start('Build: $name');
    
    // Medir en el próximo frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerformanceTracker.end('Build: $name');
    });
    
    return child;
  }
}

/// Mixin para medir lifecycle de widgets
mixin PerformanceMixin<T extends StatefulWidget> on State<T> {
  String get trackingName => T.toString();

  @override
  void initState() {
    super.initState();
    PerformanceTracker.start('$trackingName.initState');
    PerformanceTracker.end('$trackingName.initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PerformanceTracker.start('$trackingName.didChangeDependencies');
    PerformanceTracker.end('$trackingName.didChangeDependencies');
  }

  @override
  Widget build(BuildContext context) {
    PerformanceTracker.start('$trackingName.build');
    final widget = buildWithTracking(context);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerformanceTracker.end('$trackingName.build');
    });
    
    return widget;
  }

  Widget buildWithTracking(BuildContext context);

  @override
  void dispose() {
    PerformanceTracker.start('$trackingName.dispose');
    super.dispose();
    PerformanceTracker.end('$trackingName.dispose');
  }
}

// ============================================
// EJEMPLO DE USO EN TU APP
// ============================================

// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🎯 Medir inicialización de Firebase
  PerformanceTracker.start('Firebase Init');
  // await Firebase.initializeApp();
  PerformanceTracker.end('Firebase Init');
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 🎯 Escuchar cambios de estado de app
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // 📱 App minimizada
        PerformanceTracker.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // 📱 App maximizada - AQUÍ SE MIDE LA DEMORA
        PerformanceTracker.start('App Maximization');
        PerformanceTracker.onAppResumed();
        
        // Medir en próximo frame cuando UI esté lista
        WidgetsBinding.instance.addPostFrameCallback((_) {
          PerformanceTracker.end('App Maximization');
          // Mostrar reporte después de maximizar
          Future.delayed(const Duration(seconds: 1), () {
            print(PerformanceTracker.getReport());
          });
        });
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
    );
  }
}

// Ejemplo: Página con medición
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with PerformanceMixin {
  List<String> _data = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 🎯 Medir carga de datos
    PerformanceTracker.start('Load Data');
    
    // Simular carga de Firebase/API
    await Future.delayed(const Duration(milliseconds: 500));
    _data = List.generate(100, (i) => 'Item $i');
    
    PerformanceTracker.end('Load Data');
    
    if (mounted) setState(() {});
  }

  @override
  Widget buildWithTracking(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              // Mostrar reporte en un diálogo
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Reporte de Rendimiento'),
                  content: SingleChildScrollView(
                    child: Text(PerformanceTracker.getReport()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        PerformanceTracker.clear();
                        Navigator.pop(context);
                      },
                      child: const Text('Limpiar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _data.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : MeasuredWidget(
              name: 'ListView',
              child: ListView.builder(
                itemCount: _data.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_data[index]),
                  );
                },
              ),
            ),
    );
  }
}

// Ejemplo: Medir operaciones asíncronas
Future<void> fetchUserData() async {
  PerformanceTracker.start('Fetch User Data');
  
  try {
    // Tu código de Firebase
    // final user = await FirebaseAuth.instance.currentUser;
    await Future.delayed(const Duration(milliseconds: 300));
  } finally {
    PerformanceTracker.end('Fetch User Data');
  }
}

// Ejemplo: Medir navegación
void navigateToScreen(BuildContext context, Widget screen) {
  PerformanceTracker.start('Navigate to ${screen.runtimeType}');
  
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => screen),
  ).then((_) {
    PerformanceTracker.end('Navigate to ${screen.runtimeType}');
  });
}
