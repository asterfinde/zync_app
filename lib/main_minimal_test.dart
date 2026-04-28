// Test minimal con métricas de performance - Point 20
// Uso: flutter run -t lib/main_minimal_test.dart
// 
// OBJETIVO: Medir exactamente dónde está el cuello de botella

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/firebase_options.dart';
import 'package:nunakin_app/core/services/session_cache_service.dart';
import 'package:nunakin_app/core/services/native_state_bridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final startTime = DateTime.now();
  print('\n🚀 [TEST] ========== INICIO main() ==========');
  print('🕐 [TEST] Timestamp: $startTime');
  
  // Firebase Init (bloqueante)
  final firebaseStart = DateTime.now();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final firebaseDuration = DateTime.now().difference(firebaseStart);
  print('⏱️ [TEST] Firebase Init: ${firebaseDuration.inMilliseconds}ms');
  
  // SessionCache Init (bloqueante, ANTES de runApp)
  final cacheInitStart = DateTime.now();
  await SessionCacheService.init();
  final cacheInitDuration = DateTime.now().difference(cacheInitStart);
  print('⏱️ [TEST] SessionCache Init: ${cacheInitDuration.inMilliseconds}ms');
  
  // 🚀 FASE 1: Verificar estado nativo de Kotlin
  final nativeStart = DateTime.now();
  final nativeUserId = await NativeStateBridge.getUserId();
  final nativeDuration = DateTime.now().difference(nativeStart);
  print('⏱️ [TEST] Native State Read: ${nativeDuration.inMilliseconds}ms');
  if (nativeUserId != null && nativeUserId.isNotEmpty) {
    print('✅ [TEST] Estado nativo encontrado: $nativeUserId');
    print('🚀 [TEST] Flutter puede usar esto para restaurar más rápido');
  } else {
    print('ℹ️ [TEST] No hay estado nativo guardado');
  }
  
  final totalInitDuration = DateTime.now().difference(startTime);
  print('⏱️ [TEST] Total Init (bloqueante): ${totalInitDuration.inMilliseconds}ms');
  print('🚀 [TEST] ========== FIN main() ==========\n');
  
  runApp(MinimalTestApp(initTime: startTime));
}

class MinimalTestApp extends StatefulWidget {
  final DateTime initTime;
  
  const MinimalTestApp({super.key, required this.initTime});

  @override
  State<MinimalTestApp> createState() => _MinimalTestAppState();
}

class _MinimalTestAppState extends State<MinimalTestApp> with WidgetsBindingObserver {
  DateTime? _lastResumeTime;
  DateTime? _lastPauseTime;
  int _resumeCount = 0;
  Map<String, String>? _cachedSession;
  User? _currentUser;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('\n📱 [TEST] initState() - App creada');
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    final start = DateTime.now();
    
    // Test SessionCache restore - SYNC primero (0ms)
    print('🔍 [TEST] ANTES de restoreSessionSync()');
    final cacheStart = DateTime.now();
    print('🔍 [TEST] Llamando restoreSessionSync()...');
    _cachedSession = SessionCacheService.restoreSessionSync();
    print('🔍 [TEST] DESPUÉS de restoreSessionSync()');
    final cacheDuration = DateTime.now().difference(cacheStart);
    print('🔍 [TEST] Calculado cacheDuration: ${cacheDuration.inMilliseconds}ms');
    
    // IMPRIMIR INMEDIATAMENTE para evitar event loop delay
    print('⏱️ [TEST] Cache Restore (sync): ${cacheDuration.inMilliseconds}ms');
    print('💾 [TEST] Cache Data: ${_cachedSession ?? "NULL"}');
    
    // Si no hay en memoria, usar async
    if (_cachedSession == null) {
      print('⚠️ [TEST] No hay cache en memoria, usando async...');
      final asyncStart = DateTime.now();
      _cachedSession = await SessionCacheService.restoreSession();
      final asyncDuration = DateTime.now().difference(asyncStart);
      print('⏱️ [TEST] Cache Restore (async): ${asyncDuration.inMilliseconds}ms');
    }
    
    // Test Firebase Auth current user
    final authStart = DateTime.now();
    _currentUser = FirebaseAuth.instance.currentUser;
    final authDuration = DateTime.now().difference(authStart);
    print('⏱️ [TEST] Firebase Auth Check: ${authDuration.inMilliseconds}ms');
    print('👤 [TEST] Current User: ${_currentUser?.uid ?? "NULL"}');
    
    // 🚀 FASE 1: Sincronizar userId con Kotlin si hay usuario
    if (_currentUser != null) {
      final syncStart = DateTime.now();
      await NativeStateBridge.setUserId(
        userId: _currentUser!.uid,
        email: _currentUser!.email ?? '',
      );
      final syncDuration = DateTime.now().difference(syncStart);
      print('⏱️ [TEST] Native Sync: ${syncDuration.inMilliseconds}ms');
    }
    
    final totalDuration = DateTime.now().difference(start);
    print('⏱️ [TEST] Total Initial Load: ${totalDuration.inMilliseconds}ms\n');
    
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      _lastPauseTime = DateTime.now();
      print('\n📉 [TEST] ========== APP MINIMIZADA ==========');
      print('🕐 [TEST] Timestamp: $_lastPauseTime');
      
      // 🚀 FASE 1: Keep-alive ahora es NATIVO (se inicia desde MainActivity.onPause)
      print('ℹ️ [TEST] Keep-alive se maneja desde Kotlin - NO desde Flutter');
      
      // Test guardar sesión
      if (_currentUser != null) {
        final saveStart = DateTime.now();
        SessionCacheService.saveSession(
          userId: _currentUser!.uid,
          email: _currentUser!.email ?? '',
        ).then((_) {
          final saveDuration = DateTime.now().difference(saveStart);
          print('⏱️ [TEST] Cache Save: ${saveDuration.inMilliseconds}ms');
          print('💾 [TEST] Sesión guardada: ${_currentUser!.uid}');
        });
      } else {
        print('⚠️ [TEST] No hay usuario para guardar');
      }
      print('📉 [TEST] ====================================\n');
    } 
    else if (state == AppLifecycleState.resumed) {
      _lastResumeTime = DateTime.now();
      _resumeCount++;
      
      print('\n📈 [TEST] ========== APP MAXIMIZADA ==========');
      print('🕐 [TEST] Timestamp: $_lastResumeTime');
      print('🔢 [TEST] Resume #$_resumeCount');
      
      // 🚀 FASE 1: Keep-alive ahora es NATIVO (se detiene desde MainActivity.onResume)
      print('ℹ️ [TEST] Keep-alive se maneja desde Kotlin - NO desde Flutter');
      
      if (_lastPauseTime != null) {
        final pauseDuration = _lastResumeTime!.difference(_lastPauseTime!);
        print('⏱️ [TEST] Tiempo en background: ${pauseDuration.inSeconds}s');
      }
      
      // Medir restauración
      _measureResumePerformance();
      
      if (mounted) setState(() {});
    }
  }
  
  Future<void> _measureResumePerformance() async {
    final resumeStart = DateTime.now();
    
    // 1. Restaurar cache
    final cacheStart = DateTime.now();
    final restoredSession = await SessionCacheService.restoreSession();
    final cacheDuration = DateTime.now().difference(cacheStart);
    print('⏱️ [TEST] Cache Restore: ${cacheDuration.inMilliseconds}ms');
    print('💾 [TEST] Cache restaurado: ${restoredSession?["userId"] ?? "NULL"}');
    
    // 2. Verificar Firebase Auth
    final authStart = DateTime.now();
    final currentUser = FirebaseAuth.instance.currentUser;
    final authDuration = DateTime.now().difference(authStart);
    print('⏱️ [TEST] Firebase Auth Check: ${authDuration.inMilliseconds}ms');
    print('👤 [TEST] User actual: ${currentUser?.uid ?? "NULL"}');
    
    final totalResumeDuration = DateTime.now().difference(resumeStart);
    print('⏱️ [TEST] Total Resume: ${totalResumeDuration.inMilliseconds}ms');
    
    // Diagnóstico
    if (restoredSession != null && currentUser != null) {
      if (restoredSession['userId'] == currentUser.uid) {
        print('✅ [TEST] Cache válido y sincronizado');
      } else {
        print('⚠️ [TEST] Cache desincronizado!');
      }
    } else if (restoredSession == null && currentUser != null) {
      print('⚠️ [TEST] Cache vacío pero usuario autenticado');
    } else if (restoredSession != null && currentUser == null) {
      print('❌ [TEST] Cache existe pero sesión inválida');
    }
    
    print('📈 [TEST] ====================================\n');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                const Center(
                  child: Text(
                    '🔬 Performance Test',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Métricas
                _buildMetricCard('App Init', widget.initTime.toString()),
                _buildMetricCard('Resume Count', '$_resumeCount veces'),
                _buildMetricCard(
                  'Última Pausa', 
                  _lastPauseTime?.toString() ?? 'N/A',
                  color: Colors.red,
                ),
                _buildMetricCard(
                  'Último Resume', 
                  _lastResumeTime?.toString() ?? 'N/A',
                  color: Colors.green,
                ),
                
                const SizedBox(height: 16),
                const Divider(color: Colors.grey),
                const SizedBox(height: 16),
                
                // Estado Session Cache
                _buildSectionTitle('💾 Session Cache'),
                _buildDataCard(
                  'User ID',
                  _cachedSession?['userId'] ?? 'No guardado',
                ),
                _buildDataCard(
                  'Email',
                  _cachedSession?['email'] ?? 'N/A',
                ),
                _buildDataCard(
                  'Last Save',
                  _cachedSession?['lastSave'] ?? 'N/A',
                ),
                
                const SizedBox(height: 16),
                const Divider(color: Colors.grey),
                const SizedBox(height: 16),
                
                // Estado Firebase Auth
                _buildSectionTitle('🔐 Firebase Auth'),
                _buildDataCard(
                  'Current User',
                  _currentUser?.uid ?? 'No autenticado',
                ),
                _buildDataCard(
                  'Email',
                  _currentUser?.email ?? 'N/A',
                ),
                
                const SizedBox(height: 24),
                
                // Instrucciones
                const Text(
                  '📱 Instrucciones:',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInstruction('1', 'Observa las métricas actuales'),
                _buildInstruction('2', 'Presiona HOME para minimizar'),
                _buildInstruction('3', 'Espera 5-10 segundos'),
                _buildInstruction('4', 'Vuelve a abrir la app'),
                _buildInstruction('5', 'Revisa los logs en la consola'),
                
                const SizedBox(height: 24),
                
                // Botón refresh
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      print('\n🔄 [TEST] Refresh manual');
                      await _loadInitialData();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1EE9A4),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMetricCard(String label, String value, {Color? color}) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: color ?? const Color(0xFF1EE9A4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildDataCard(String label, String value) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInstruction(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$number. ',
            style: const TextStyle(
              color: Color(0xFF1EE9A4),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
