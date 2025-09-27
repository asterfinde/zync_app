import '../../../../dev_utils/clean_firestore.dart';
import '../../../../dev_utils/clean_auth.dart';
// lib/features/circle/presentation/pages/home_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zync_app/features/circle/services/emoji_notification_service.dart';
import 'package:zync_app/features/circle/services/quick_status_service.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
import 'package:zync_app/features/auth/presentation/pages/auth_final_page.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_state.dart';
import 'package:zync_app/features/circle/presentation/widgets/in_circle_view.dart';
import 'package:zync_app/features/circle/presentation/widgets/no_circle_view.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      log('Notification permission has been granted.');
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
    String userNickname = (authState is Authenticated) ? authState.user.nickname : '';
    String userEmail = (authState is Authenticated) ? authState.user.email : '';
    log('[UI] HomePage: nickname recibido: "$userNickname", email recibido: "$userEmail"');
    if (userNickname.trim().isEmpty) {
      userNickname = userEmail.isNotEmpty ? userEmail : 'Sin nickname';
    }
    final accentColor = Colors.tealAccent.shade400;

    // Lógica para manejar el servicio de fondo
    ref.listen<CircleState>(circleProvider, (previous, next) {
      final userId = (authState is Authenticated) ? authState.user.uid : null;
      if (userId == null) return;

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

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is Unauthenticated) {
        log('User signed out. Stopping foreground service...');
        QuickStatusService.stopService();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zync'),
            Text(
              userNickname,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          // Solo en debug: botón de limpieza masiva
          if (const bool.fromEnvironment('dart.vm.product') == false)
            IconButton(
              key: const ValueKey('clean_all_button'),
              icon: const Icon(Icons.delete_forever),
              tooltip: 'LIMPIEZA MASIVA (Firestore + Auth)',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Eliminar TODOS los datos?'),
                    content: const Text('Esta acción eliminará TODOS los usuarios y círculos de Firestore y Auth. Solo para desarrollo.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                    ],
                  ),
                );
                if (confirmed != true) return;
                try {
                  await cleanFirestoreCollections();
                  await cleanAuthUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Limpieza masiva completada!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error en limpieza: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthFinalPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final circleState = ref.watch(circleProvider);
          return switch (circleState) {
            CircleInitial() => const Center(child: Text("Iniciando círculo...")),
            CircleLoading() => const Center(child: CircularProgressIndicator()),
            NoCircle() => const NoCircleView(),
            CircleLoaded(:final circle) => InCircleView(circle: circle),
            CircleError(:final message) => Center(child: Text('Error: $message')),
            _ => const SizedBox.shrink(),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        onPressed: () {
          QuickStatusService.showSelectorUI(context);
        },
        child: const Icon(Icons.add_reaction_outlined, color: Colors.black),
      ),
    );
  }
}