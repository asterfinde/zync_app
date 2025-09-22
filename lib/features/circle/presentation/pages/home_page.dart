// lib/features/circle/presentation/pages/home_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zync_app/features/circle/services/quick_status_service.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_state.dart';
import 'package:zync_app/features/circle/presentation/pages/quick_status_selector_page.dart';
import 'package:zync_app/features/circle/presentation/widgets/in_circle_view.dart';
import 'package:zync_app/features/circle/presentation/widgets/no_circle_view.dart';
import 'package:zync_app/main.dart';

// --- CAMBIO 1: Convertir a ConsumerStatefulWidget para tener acceso a initState ---
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // --- CAMBIO 2: Mover la lógica de permisos a initState ---
  // initState se ejecuta UNA SOLA VEZ cuando el widget se inserta en la pantalla.
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Pedimos el permiso de notificación.
    final status = await Permission.notification.request();
    if (status.isGranted) {
      log('Notification permission has been granted.');
      
      // 🎯 AUTOMATIZAR: Crear notificación emoji automáticamente
      try {
        await EmojiNotificationService.requestNotificationPermission();
        await EmojiNotificationService.showNotification();
        log('✅ Notificación emoji creada automáticamente');
      } catch (e) {
        log('❌ Error creando notificación emoji: $e');
      }
    } else {
      log('Notification permission has been denied.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userEmail = authState is Authenticated ? authState.user.email : '...';

    // Escuchamos los cambios en el estado del círculo para gestionar el servicio.
    ref.listen<CircleState>(circleProvider, (previous, next) {
      final userId = (authState is Authenticated) ? authState.user.uid : null;
      if (userId == null) return;

      // --- CAMBIO 3: La lógica aquí ahora es más simple ---
      // Solo se preocupa de iniciar/detener el servicio, no de los permisos.
      if (next is CircleLoaded) {
        log('Circle loaded. Starting foreground service...');
        QuickStatusService.startService(
          userId: userId,
          circleId: next.circle.id,
        );
      } else if (previous is CircleLoaded && next is! CircleLoaded) {
        log('User left circle. Stopping foreground service...');
        QuickStatusService.stopService();
      }
    });

    // El resto del widget permanece igual...
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is Unauthenticated) {
        log('User signed out. Stopping foreground service...');
        QuickStatusService.stopService();
      }
    });

    // Removed unused variable 'circleState'

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zync'),
            Text(
              userEmail,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // BOTÓN TEMPORAL DE PRUEBA
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                log('[HOME] Botón de prueba presionado - abriendo modal');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const QuickStatusSelectorPage(),
                    fullscreenDialog: true,
                  ),
                );
              },
              child: const Text('🧪 PRUEBA: Abrir Modal Emojis'),
            ),
          ),
          // CONTENIDO ORIGINAL
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final circleState = ref.watch(circleProvider);
                return switch (circleState) {
                  CircleInitial() => const SizedBox.shrink(),
                  CircleLoading() => const CircularProgressIndicator(),
                  NoCircle() => const NoCircleView(),
                  CircleLoaded(circle: final circle) => InCircleView(circle: circle),
                  CircleError(message: final msg) => Text('Error: $msg'),
                  _ => const SizedBox.shrink(),
                };
              },
            ),
          ),
        ],
      ),
      // 🚀 TAREA 1: FloatingActionButton Global
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          log('[FAB] Quick Status FAB presionado');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const QuickStatusSelectorPage(),
              fullscreenDialog: true,
            ),
          );
        },
        tooltip: 'Estado Rápido',
        child: const Icon(Icons.mood),
      ),
    );
  }
}