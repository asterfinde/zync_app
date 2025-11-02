// main.dart - Optimizaciones críticas

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  // 1️⃣ CRÍTICO: WidgetsFlutterBinding antes de CUALQUIER cosa
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2️⃣ Configurar orientación ANTES de inicializar Firebase
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // 3️⃣ Firebase initialization LAZY (solo cuando se necesite)
  // ❌ MAL: await Firebase.initializeApp();
  // ✅ BIEN: Inicializar en splash o cuando hagas login
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 4️⃣ Desactivar checkerboard y debug banner
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: false,
      
      // 5️⃣ Theme simple (evitar Theme muy complejos)
      theme: ThemeData(
        useMaterial3: true,
        // Usa colores directos, no gradientes pesados
      ),
      
      // 6️⃣ Home ligero: NO cargar todo en HomePage
      home: const SplashOrHome(),
    );
  }
}

// 7️⃣ Pantalla inicial MINIMALISTA
class SplashOrHome extends StatefulWidget {
  const SplashOrHome({super.key});

  @override
  State<SplashOrHome> createState() => _SplashOrHomeState();
}

class _SplashOrHomeState extends State<SplashOrHome> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 8️⃣ Cargar datos SOLO si es necesario
    // Chequear si hay sesión guardada en SharedPreferences
    final hasSession = await _checkSession();
    
    if (hasSession) {
      // Usuario ya logueado: ir directo a Home
      // Firebase se inicializa DESPUÉS en background
      _initFirebaseInBackground();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } else {
      // No hay sesión: ir a Login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Placeholder()), // Placeholder - reemplazar con tu LoginPage
        );
      }
    }
  }

  Future<bool> _checkSession() async {
    // Verificar token guardado (super rápido)
    // NO llamar a Firebase aquí
    return false; // Placeholder
  }

  void _initFirebaseInBackground() {
    // Inicializar Firebase DESPUÉS de mostrar UI
    Future.delayed(Duration.zero, () async {
      // await Firebase.initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 9️⃣ Splash MINIMALISTA: solo logo, sin animaciones pesadas
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// 🔟 HomePage: Lazy loading de widgets pesados
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  // ✅ AutomaticKeepAliveClientMixin mantiene estado al minimizar
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // IMPORTANTE para AutomaticKeepAliveClientMixin
    
    return Scaffold(
      body: ListView.builder(
        // 1️⃣1️⃣ Usar ListView.builder (lazy) en vez de Column con muchos widgets
        itemCount: 100,
        itemBuilder: (context, index) {
          return ListTile(title: Text('Item $index'));
        },
      ),
    );
  }
}

// 1️⃣2️⃣ Widgets con const constructors
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Use const siempre que puedas');
  }
}
