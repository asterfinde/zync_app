import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/provider/auth_provider.dart';
import '../provider/circle_provider.dart';
import '../provider/circle_state.dart';
import '../widgets/in_circle_view.dart';
import '../widgets/no_circle_view.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log("[HomePage] HU: Reconstruyendo HomePage...");
    final circleState = ref.watch(circleProvider);
    log("[HomePage] HU: El estado actual del círculo es: ${circleState.runtimeType}");

    Widget body;
    switch (circleState) {
      case CircleInitial():
      case CircleLoading():
        log("[HomePage] HU: Mostrando CircularProgressIndicator.");
        body = const CircularProgressIndicator();
        break;
      case NoCircle():
        log("[HomePage] HU: Mostrando NoCircleView.");
        body = const NoCircleView();
        break;
      case InCircle(circle: final circle):
        log("[HomePage] HU: Mostrando InCircleView para el círculo '${circle.name}'.");
        body = InCircleView(circle: circle);
        break;
      case CircleError(message: final msg):
        log("[HomePage] HU: Mostrando pantalla de Error: $msg");
        body = Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: $msg', textAlign: TextAlign.center),
          );
        break;
      default:
        body = const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              log("[HomePage] HU: Botón de Logout presionado.");
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: Center(child: body),
    );
  }
}

// // lib/features/circle/presentation/pages/home_page.dart

// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../../auth/presentation/provider/auth_provider.dart';
// import '../provider/circle_provider.dart';
// import '../provider/circle_state.dart';
// import '../widgets/in_circle_view.dart';
// import '../widgets/no_circle_view.dart';

// class HomePage extends ConsumerWidget {
//   const HomePage({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     log("[BUILD] HomePage rebuilding... Authentication successful!");
//     final circleState = ref.watch(circleProvider);
//     log("[HomePage] Watching circleState. Current state is: $circleState");

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Zync'),
//         actions: [
//           // --- ÚNICO CAMBIO ---
//           // Se elimina la condición 'if (circleState is InCircle)' para que el
//           // botón de logout esté siempre visible, incluso en la pantalla de error.
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () {
//               log("[HomePage] Logout button pressed. Triggering signOut...");
//               ref.read(authProvider.notifier).signOut();
//             },
//           ),
//         ],
//       ),
//       body: Center(
//         child: switch (circleState) {
//           CircleInitial() ||
//           CircleLoading() =>
//             const CircularProgressIndicator(),
//           NoCircle() => const NoCircleView(),
//           InCircle(circle: final circle) => InCircleView(circle: circle),
//           CircleError(message: final msg) => Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Text('Error: $msg', textAlign: TextAlign.center),
//           ),
//           _ => const SizedBox.shrink(),
//         },
//       ),
//     );
//   }
// }


// // // /lib/features/circle/presentation/pages/home_page.dart

// // import 'dart:developer';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';

// // import '../../../auth/presentation/provider/auth_provider.dart';
// // import '../provider/circle_provider.dart';
// // import '../provider/circle_state.dart';
// // import '../widgets/in_circle_view.dart';
// // import '../widgets/no_circle_view.dart';

// // class HomePage extends ConsumerWidget {
// //   const HomePage({super.key});

// //   @override
// //   Widget build(BuildContext context, WidgetRef ref) {
// //     log("[BUILD] HomePage rebuilding... Authentication successful!");
// //     final circleState = ref.watch(circleProvider);
// //     log("[HomePage] Watching circleState. Current state is: $circleState");

// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text('Zync'),
// //         actions: [
// //           if (circleState is InCircle)
// //             IconButton(
// //               icon: const Icon(Icons.logout),
// //               onPressed: () {
// //                 log("[HomePage] Logout button pressed. Triggering signOut...");
// //                 ref.read(authProvider.notifier).signOut();
// //               },
// //             ),
// //         ],
// //       ),
// //       body: Center(
// //         child: switch (circleState) {
// //           CircleInitial() ||
// //           CircleLoading() =>
// //             const CircularProgressIndicator(),
// //           NoCircle() => const NoCircleView(),
// //           InCircle(circle: final circle) => InCircleView(circle: circle),
// //           CircleError(message: final msg) => Text('Error: $msg'),
// //           _ => const SizedBox.shrink(),
// //         },
// //       ),
// //     );
// //   }
// // }