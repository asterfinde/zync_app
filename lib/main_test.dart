// lib/main_test.dart
// APP DE PRUEBA MÍNIMA PARA TESTING MIN/MAX PERFORMANCE

import 'package:flutter/material.dart';
import 'test_helpers/test_cache.dart';
import 'test_helpers/test_page.dart';
import 'test_helpers/performance_monitor.dart';

void main() async {
  print('\n🚀 ===== INICIANDO APP DE PRUEBA =====');
  PerformanceMonitor.start('AppInit');
  
  WidgetsFlutterBinding.ensureInitialized();
  
  // SOLO inicializar cache - nada más
  print('📦 Inicializando TestCache...');
  await TestCache.init();
  
  PerformanceMonitor.stop('AppInit');
  PerformanceMonitor.printSummary();
  
  runApp(const TestApp());
  
  print('✅ ===== APP DE PRUEBA INICIADA =====\n');
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Min/Max Performance',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TestPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
