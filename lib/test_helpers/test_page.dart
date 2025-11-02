import 'package:flutter/material.dart';
import 'test_cache.dart';
import 'performance_monitor.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with WidgetsBindingObserver {
  List<String> _items = [];
  bool _isFromCache = false;
  int _loadTime = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Guardar al cerrar
    TestCache.saveList(_items);
    print('💾 [TestPage] Datos guardados en dispose()');
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print('📱 [TestPage] App minimizada - Guardando...');
      TestCache.saveList(_items);
    } else if (state == AppLifecycleState.resumed) {
      print('📱 [TestPage] App maximizada - Cargando...');
      _loadData();
    }
  }
  
  void _loadData() {
    PerformanceMonitor.start('LoadData');
    
    // Intentar cargar desde cache
    final cachedItems = TestCache.loadList();
    
    if (cachedItems.isNotEmpty) {
      // CACHE HIT
      setState(() {
        _items = cachedItems;
        _isFromCache = true;
        _loadTime = PerformanceMonitor.stop('LoadData');
      });
    } else {
      // CACHE MISS - Generar datos
      setState(() {
        _items = List.generate(10, (i) => 'Item ${i + 1} - ${DateTime.now()}');
        _isFromCache = false;
        _loadTime = PerformanceMonitor.stop('LoadData');
      });
      
      // Guardar para próxima vez
      TestCache.saveList(_items);
    }
    
    PerformanceMonitor.printSummary();
  }
  
  void _reload() {
    setState(() {
      _items = List.generate(10, (i) => 'Item ${i + 1} - ${DateTime.now()}');
    });
    TestCache.saveList(_items);
    print('🔄 [TestPage] Datos recargados manualmente');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('TEST: Min/Max Performance'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicadores de performance
          Container(
            padding: const EdgeInsets.all(16),
            color: _isFromCache ? Colors.green.shade900 : Colors.red.shade900,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isFromCache ? Icons.check_circle : Icons.warning,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isFromCache ? '🟢 CACHE HIT' : '🔴 CACHE MISS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Load Time: ${_loadTime}ms',
                  style: TextStyle(
                    color: _loadTime < 100 ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Instrucciones
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[800],
            child: const Text(
              '📱 TEST: Minimiza la app (Home) → Maximiza (Recent Apps)\n'
              '✅ Debería cargar instantáneamente con "CACHE HIT"\n'
              '⏱️ Load Time debe ser <100ms',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Lista de items
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.tealAccent,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    _items[index],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Index: $index',
                    style: const TextStyle(color: Colors.white60),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _reload,
        backgroundColor: Colors.tealAccent,
        child: const Icon(Icons.refresh, color: Colors.black),
      ),
    );
  }
}
