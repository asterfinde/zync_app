// lib/features/circle/presentation/pages/home_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart'; // AÑADIDO: Import para la gestión de permisos.
import 'package:zync_app/features/circle/services/quick_status_service.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_state.dart';
import 'package:zync_app/features/circle/presentation/widgets/in_circle_view.dart';
import 'package:zync_app/features/circle/presentation/widgets/no_circle_view.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userEmail = authState is Authenticated ? authState.user.email : '...';
    
    // Escuchamos los cambios en el estado del círculo para gestionar el servicio.
    ref.listen<CircleState>(circleProvider, (previous, next) {
      final userId = (authState is Authenticated) ? authState.user.uid : null;
      if (userId == null) return; // No hacer nada si no hay usuario

      // --- INICIO DE LA MODIFICACIÓN ---
      // Si el nuevo estado es 'CircleLoaded', solicitamos permisos y luego iniciamos el servicio.
      if (next is CircleLoaded) {
        // Usamos una función anónima asíncrona para manejar los permisos.
        () async {
          var status = await Permission.notification.status;
          // Si el permiso está denegado, lo solicitamos.
          if (status.isDenied) {
            status = await Permission.notification.request();
          }

          // Solo si el permiso es concedido, iniciamos el servicio.
          if (status.isGranted) {
            log('Notification permission granted. Starting foreground service...');
            QuickStatusService.startService(
              userId: userId,
              circleId: next.circle.id,
            );
          } else {
            log('Notification permission denied. Cannot start foreground service.');
            // Opcional: Aquí se podría mostrar un mensaje al usuario.
          }
        }(); // Se invoca la función anónima inmediatamente.
      } 
      // --- FIN DE LA MODIFICACIÓN ---
      // Si el estado anterior era 'CircleLoaded' y el nuevo no lo es, detenemos el servicio.
      else if (previous is CircleLoaded && next is! CircleLoaded) {
        log('User left circle. Stopping foreground service...');
        QuickStatusService.stopService();
      }
    });

    // Escuchamos cambios en la autenticación para detener el servicio al cerrar sesión.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is Unauthenticated) {
        log('User signed out. Stopping foreground service...');
        QuickStatusService.stopService();
      }
    });

    final circleState = ref.watch(circleProvider);

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

// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// // CORRECCIÓN: usar imports con "package:" para evitar problemas de resolución.
// import 'package:zync_app/features/circle/services/quick_status_service.dart';
// import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
// import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
// import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
// import 'package:zync_app/features/circle/presentation/provider/circle_state.dart';
// import 'package:zync_app/features/circle/presentation/widgets/in_circle_view.dart';
// import 'package:zync_app/features/circle/presentation/widgets/no_circle_view.dart';

// class HomePage extends ConsumerWidget {
//   const HomePage({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final authState = ref.watch(authProvider);
//     final userEmail = authState is Authenticated ? authState.user.email : '...';
    
//     // Escuchamos los cambios en el estado del círculo para gestionar el servicio.
//     ref.listen<CircleState>(circleProvider, (previous, next) {
//       final userId = (authState is Authenticated) ? authState.user.uid : null;
//       if (userId == null) return; // No hacer nada si no hay usuario

//       // Si el nuevo estado es 'CircleLoaded', iniciamos el servicio.
//       if (next is CircleLoaded) {
//         log('Circle loaded. Starting foreground service...');
//         QuickStatusService.startService(
//           userId: userId,
//           circleId: next.circle.id,
//         );
//       } 
//       // Si el estado anterior era 'CircleLoaded' y el nuevo no lo es, detenemos el servicio.
//       else if (previous is CircleLoaded && next is! CircleLoaded) {
//         log('User left circle. Stopping foreground service...');
//         QuickStatusService.stopService();
//       }
//     });

//     // Escuchamos cambios en la autenticación para detener el servicio al cerrar sesión.
//     ref.listen<AuthState>(authProvider, (previous, next) {
//       if (next is Unauthenticated) {
//         log('User signed out. Stopping foreground service...');
//         QuickStatusService.stopService();
//       }
//     });

//     final circleState = ref.watch(circleProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Zync'),
//             Text(
//               userEmail,
//               style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () => ref.read(authProvider.notifier).signOut(),
//           ),
//         ],
//       ),
//       body: Center(
//         child: switch (circleState) {
//           CircleInitial() || CircleLoading() => const CircularProgressIndicator(),
//           NoCircle() => const NoCircleView(),
//           CircleLoaded(circle: final circle) => InCircleView(circle: circle),
//           CircleError(message: final msg) => Text('Error: $msg'),
//           _ => const SizedBox.shrink(),
//         },
//       ),
//     );
//   }
// }