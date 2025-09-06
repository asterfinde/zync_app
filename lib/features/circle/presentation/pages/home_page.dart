// lib/features/circle/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/provider/auth_provider.dart';
import '../../../auth/presentation/provider/auth_state.dart';
import '../provider/circle_provider.dart';
import '../provider/circle_state.dart';
import '../widgets/in_circle_view.dart';
import '../widgets/no_circle_view.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Esta línea ahora funcionará porque circle_provider.dart compilará correctamente
    final circleState = ref.watch(circleProvider);
    final authState = ref.watch(authProvider);
    final userEmail = authState is Authenticated ? authState.user.email : '...';

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
      body: Center(
        child: switch (circleState) {
          CircleInitial() || CircleLoading() => const CircularProgressIndicator(),
          NoCircle() => const NoCircleView(),
          CircleLoaded(circle: final circle) => InCircleView(circle: circle),
          CircleError(message: final msg) => Text('Error: $msg'),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}