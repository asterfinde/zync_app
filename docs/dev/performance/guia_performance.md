## 🚀 Guía Paso a Paso en VSCode

### Paso 1: Crear los Archivos

```bash
# En la terminal de VSCode (Ctrl + `)
mkdir lib/utils
touch lib/utils/performance_tracker.dart
```

### Paso 2: Copiar el Código del Tracker

**Archivo: `lib/utils/performance_tracker.dart`**

Copia **SOLO la clase `PerformanceTracker`** del artifact (las primeras 100 líneas):

```dart
// lib/utils/performance_tracker.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PerformanceTracker {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, Duration> _measurements = {};
  static DateTime? _appPausedAt;
  static DateTime? _appResumedAt;

  static void start(String operation) {
    _startTimes[operation] = DateTime.now();
    if (kDebugMode) {
      print('⏱️ [START] $operation');
    }
  }

  static void end(String operation) {
    if (_startTimes.containsKey(operation)) {
      final duration = DateTime.now().difference(_startTimes[operation]!);
      _measurements[operation] = duration;
      
      final color = duration.inMilliseconds > 300 ? '🔴' : '✅';
      if (kDebugMode) {
        print('$color [END] $operation - ${duration.inMilliseconds}ms');
      }
      
      _startTimes.remove(operation);
    }
  }

  static void onAppPaused() {
    _appPausedAt = DateTime.now();
    if (kDebugMode) {
      print('⏸️ [APP] Minimizada a las ${_appPausedAt}');
    }
  }

  static void onAppResumed() {
    _appResumedAt = DateTime.now();
    if (_appPausedAt != null) {
      final pausedDuration = _appResumedAt!.difference(_appPausedAt!);
      if (kDebugMode) {
        print('▶️ [APP] Restaurada después de ${pausedDuration.inSeconds}s');
      }
    }
  }

  static String getReport() {
    final buffer = StringBuffer();
    buffer.writeln('\n📊 === REPORTE DE RENDIMIENTO ===\n');
    
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

  static void clear() {
    _measurements.clear();
    _startTimes.clear();
  }
}
```

### Paso 3: Modificar Tu `main.dart`

**Archivo: `lib/main.dart`** (modifica el que ya tienes)

```dart
import 'package:flutter/material.dart';
import 'utils/performance_tracker.dart'; // ← AGREGAR

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🎯 Medir Firebase si lo usas
  PerformanceTracker.start('Firebase Init');
  // await Firebase.initializeApp(); // Si usas Firebase
  PerformanceTracker.end('Firebase Init');
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // ✅ CRÍTICO: Escuchar cambios de estado de app
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
        print('📱 App MINIMIZADA');
        PerformanceTracker.onAppPaused();
        break;
        
      case AppLifecycleState.resumed:
        print('📱 App MAXIMIZADA - Midiendo...');
        PerformanceTracker.start('App Maximization');
        PerformanceTracker.onAppResumed();
        
        // Medir cuando UI esté lista
        WidgetsBinding.instance.addPostFrameCallback((_) {
          PerformanceTracker.end('App Maximization');
          
          // Mostrar reporte después de 1 segundo
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
      title: 'Zync App',
      // ... tu configuración actual
      home: const HomePage(), // Tu página principal
    );
  }
}

// Resto de tu código...
```

### Paso 4: Agregar Mediciones a Tus Páginas Importantes

**Ejemplo con tu HomePage:**

```dart
// lib/pages/home_page.dart
import '../utils/performance_tracker.dart'; // ← AGREGAR

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    PerformanceTracker.start('HomePage.initState');
    
    _loadInitialData();
    
    PerformanceTracker.end('HomePage.initState');
  }

  Future<void> _loadInitialData() async {
    PerformanceTracker.start('Load Initial Data');
    
    // Tu código de carga (Firebase, API, etc.)
    // Por ejemplo:
    // await fetchUserProfile();
    // await loadNotifications();
    
    PerformanceTracker.end('Load Initial Data');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tu UI actual
    );
  }
}
```

### Paso 5: Ejecutar y Ver Resultados en VSCode

#### Opción A: Debug Console (Más Simple)

```bash
# Terminal en VSCode
flutter run

# Verás los logs en el panel inferior "Debug Console"
```

#### Opción B: Ver Logs en Terminal Separada

```bash
# Terminal 1: Ejecutar app
flutter run

# Terminal 2: Ver logs filtrados
# En otra terminal de VSCode (Ctrl + Shift + `)
flutter logs | grep "APP\|START\|END\|📊"
```

### Paso 6: Reproducir el Problema

1. ✅ App corriendo en tu dispositivo/emulador
2. ✅ Minimiza la app (botón Home)
3. ✅ Espera 3-5 segundos
4. ✅ Maximiza la app (toca el ícono)
5. ✅ **Mira la Debug Console** en VSCode

**Verás algo así:**

```
📱 App MINIMIZADA
⏸️ [APP] Minimizada a las 2024-10-23 14:30:25.123

(Aquí minimizas y esperas)

📱 App MAXIMIZADA - Midiendo...
▶️ [APP] Restaurada después de 5s
⏱️ [START] App Maximization
⏱️ [START] HomePage.initState
⏱️ [START] Load Initial Data
🔴 [END] Load Initial Data - 850ms  ← PROBLEMA!
✅ [END] HomePage.initState - 855ms
✅ [END] App Maximization - 920ms

📊 === REPORTE DE RENDIMIENTO ===

🔴 Load Initial Data: 850ms
🟢 HomePage.initState: 855ms
🟢 App Maximization: 920ms

=================================
```

## 🎯 Interpretación Rápida

| Emoji | Tiempo | Diagnóstico |
|-------|--------|-------------|
| 🟢 | 0-200ms | ✅ Perfecto |
| 🟡 | 200-500ms | ⚠️ Mejorable |
| 🔴 | >500ms | ❌ Problema crítico |

## 🔍 Agregar Más Mediciones

**Si quieres medir operaciones específicas:**

```dart
// Ejemplo: Medir consulta a Firebase
Future<void> fetchUserData() async {
  PerformanceTracker.start('Firebase: Get User');
  
  try {
    final user = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
    
    PerformanceTracker.end('Firebase: Get User');
    return user;
  } catch (e) {
    PerformanceTracker.end('Firebase: Get User');
    rethrow;
  }
}

// Ejemplo: Medir carga de imágenes
Widget build(BuildContext context) {
  PerformanceTracker.start('Build HomePage');
  
  final widget = Scaffold(...);
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PerformanceTracker.end('Build HomePage');
  });
  
  return widget;
}
```

## 🚨 Troubleshooting

### No veo los logs en Debug Console

```dart
// Verifica que tienes esto en main.dart
import 'package:flutter/foundation.dart';

void main() {
  // Forzar logs en debug mode
  debugPrint('🚀 App iniciando...');
  runApp(const MyApp());
}
```

### Quiero ver logs en archivo

```bash
# Redirigir logs a archivo
flutter run > logs.txt 2>&1

# O solo performance logs
flutter logs | grep "⏱️\|📊" > performance.txt
```

## 📊 Bonus: Botón de Debug en Tu App

Agrega esto a cualquier página para ver el reporte cuando quieras:

```dart
FloatingActionButton(
  onPressed: () {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Performance Report'),
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
        ],
      ),
    );
  },
  child: const Icon(Icons.speed),
)
```

---

**Nota sobre `flutter_optimizations.dart`**: Ese archivo del artifact es **código de ejemplo** para mostrar las optimizaciones. No lo copies directamente, sino que **aplica las técnicas** en tu código existente.

¿Quieres que te ayude a agregar las mediciones en algún archivo específico de tu proyecto? Compárteme el código y lo adapto.