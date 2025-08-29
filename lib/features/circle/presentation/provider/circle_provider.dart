// lib/features/circle/presentation/provider/circle_provider.dart

import 'dart:async';
import 'dart:developer';

import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart'; 
import 'package:zync_app/features/auth/presentation/provider/auth_state.dart'; 

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zync_app/features/circle/domain/usecases/update_circle_status.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/create_circle.dart';
import '../../domain/usecases/get_circle_stream_for_user.dart';
import '../../domain/usecases/join_circle.dart';
import 'circle_state.dart';

class CircleNotifier extends StateNotifier<CircleState> {
  final CreateCircle _createCircle;
  final JoinCircle _joinCircle;
  final GetCircleStreamForUser _getCircleStreamForUser;
  final UpdateCircleStatus _updateCircleStatus;
  final String? _userId;

  StreamSubscription? _circleSubscription;

  CircleNotifier({
    required CreateCircle createCircle,
    required JoinCircle joinCircle,
    required GetCircleStreamForUser getCircleStreamForUser,
    required UpdateCircleStatus updateCircleStatus,
    required String? userId,
  })  : _createCircle = createCircle,
        _joinCircle = joinCircle,
        _getCircleStreamForUser = getCircleStreamForUser,
        _updateCircleStatus = updateCircleStatus,
        _userId = userId,
        super(CircleInitial()) {
    _listenToCircleChanges();
  }

  void _listenToCircleChanges() {
    if (_userId == null) { // <- AÑADE ESTE BLOQUE if
      state = NoCircle();
      log("[CircleNotifier] HU: No hay usuario, estado -> NoCircle.");
      return;
    }

    log("[CircleNotifier] HU: Iniciando escucha de cambios del círculo...");
    state = CircleLoading();
    _circleSubscription?.cancel();
    _circleSubscription =
      _getCircleStreamForUser(GetCircleStreamParams(userId: _userId!)).listen( 
      (either) {
        log("[CircleNotifier] HU: El stream de círculo emitió nuevos datos.");
        either.fold(
          (failure) {
            log("[CircleNotifier] HU: El stream devolvió un Failure: ${failure.message}");
            state = CircleError(failure.message);
          },
          (circle) {
            if (circle != null) {
              log("[CircleNotifier] HU: El stream devolvió un Círculo: ${circle.name}. Estado -> InCircle");
              state = InCircle(circle);
            } else {
              log("[CircleNotifier] HU: El stream devolvió null. Estado -> NoCircle");
              state = NoCircle();
            }
          },
        );
      },
      onError: (e) {
        log("[CircleNotifier] HU: El stream lanzó un Error: ${e.toString()}");
        state = CircleError(e.toString());
      },
    );
  }

  Future<void> createCircle(String name) async {
    log("[CircleNotifier] HU: Acción 'createCircle' iniciada para el nombre: $name");
    state = CircleLoading();
    final result = await _createCircle(CreateCircleParams(name: name));
    result.fold(
      (failure) {
        log("[CircleNotifier] HU: 'createCircle' falló: ${failure.message}");
        state = CircleError(failure.message);
      },
      (_) => log("[CircleNotifier] HU: 'createCircle' tuvo éxito. Esperando actualización del stream."),
    );
  }

  Future<void> joinCircle(String invitationCode) async {
    log("[CircleNotifier] HU: Acción 'joinCircle' iniciada con el código: $invitationCode");
    state = CircleLoading();
    final result =
        await _joinCircle(JoinCircleParams(invitationCode: invitationCode));
    result.fold(
      (failure) {
        log("[CircleNotifier] HU: 'joinCircle' falló: ${failure.message}");
        state = CircleError(failure.message);
      },
      (_) => log("[CircleNotifier] HU: 'joinCircle' tuvo éxito. Esperando actualización del stream."),
    );
  }
  
  // El resto del archivo no necesita logs para este caso de prueba.
  // ...
  Future<void> updateCircleStatus(String newStatusEmoji) async {
    if (state is InCircle) {
      final circleId = (state as InCircle).circle.id;
      final params = UpdateCircleStatusParams(
          circleId: circleId, newStatus: newStatusEmoji);
      final result = await _updateCircleStatus(params);
      result.fold(
        (failure) => log('[CircleNotifier] Update failed: ${failure.message}'),
        (_) => log('[CircleNotifier] Update succeeded'),
      );
    }
  }

  @override
  void dispose() {
    _circleSubscription?.cancel();
    super.dispose();
  }
}

final circleProvider = StateNotifierProvider<CircleNotifier, CircleState>((ref) {
  // 1. Observa el estado de autenticación
  // (Reemplaza 'authNotifierProvider' con el nombre real de tu provider de auth)
  final authState = ref.watch(authProvider);

  // 2. Obtiene el UID solo si el usuario está autenticado
  final userId = (authState is Authenticated) ? authState.user.uid : null;

  // 3. Crea el Notifier pasándole el userId
  final notifier = CircleNotifier(
    createCircle: sl<CreateCircle>(),
    joinCircle: sl<JoinCircle>(),
    getCircleStreamForUser: sl<GetCircleStreamForUser>(),
    updateCircleStatus: sl<UpdateCircleStatus>(),
    userId: userId, // <- Pasa el userId (o null) al notifier
  );

  return notifier;
});


// // lib/features/circle/presentation/provider/circle_provider.dart

// import 'dart:async';
// import 'dart:developer';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:zync_app/features/circle/domain/usecases/update_circle_status.dart';
// import '../../../../core/di/injection_container.dart';
// import '../../domain/usecases/create_circle.dart';
// import '../../domain/usecases/get_circle_stream_for_user.dart';
// import '../../domain/usecases/join_circle.dart';
// import 'circle_state.dart';

// class CircleNotifier extends StateNotifier<CircleState> {
//   final CreateCircle _createCircle;
//   final JoinCircle _joinCircle;
//   final GetCircleStreamForUser _getCircleStreamForUser;
//   final UpdateCircleStatus _updateCircleStatus;
//   // final FirebaseAuth _firebaseAuth; // Eliminado porque no se usa

//   StreamSubscription? _circleSubscription;

//   CircleNotifier({
//     required CreateCircle createCircle,
//     required JoinCircle joinCircle,
//     required GetCircleStreamForUser getCircleStreamForUser,
//     required UpdateCircleStatus updateCircleStatus,
//     // required FirebaseAuth firebaseAuth, // Eliminado porque no se usa
//   })  : _createCircle = createCircle,
//         _joinCircle = joinCircle,
//         _getCircleStreamForUser = getCircleStreamForUser,
//         _updateCircleStatus = updateCircleStatus,
//         super(CircleInitial()) {
//     _listenToCircleChanges();
//   }

//   void _listenToCircleChanges() {
//     state = CircleLoading();
//     _circleSubscription?.cancel();
//     _circleSubscription =
//         _getCircleStreamForUser(const GetCircleStreamParams()).listen(
//       (either) {
//         either.fold(
//           (failure) {
//             state = CircleError(failure.message);
//             log('[CircleNotifier] Stream Error: ${failure.message}');
//           },
//           (circle) {
//             if (circle != null) {
//               state = InCircle(circle);
//             } else {
//               state = NoCircle();
//             }
//             log('[CircleNotifier] State Updated: ${state.runtimeType}');
//           },
//         );
//       },
//       onError: (e) => state = CircleError(e.toString()),
//     );
//   }

//   Future<void> createCircle(String name) async {
//     state = CircleLoading();
//     final result = await _createCircle(CreateCircleParams(name: name));
//     result.fold(
//       (failure) => state = CircleError(failure.message),
//       (_) => null, // El stream actualizará el estado a InCircle
//     );
//   }

//   Future<void> joinCircle(String invitationCode) async {
//     state = CircleLoading();
//     final result =
//         await _joinCircle(JoinCircleParams(invitationCode: invitationCode));
//     result.fold(
//       (failure) => state = CircleError(failure.message),
//       (_) => null, // El stream actualizará el estado a InCircle
//     );
//   }

//   // CORRECCIÓN: Método añadido
//   Future<void> updateCircleStatus(String newStatusEmoji) async {
//     if (state is InCircle) {
//       final circleId = (state as InCircle).circle.id;
//       final params = UpdateCircleStatusParams(
//           circleId: circleId, newStatus: newStatusEmoji);
//       final result = await _updateCircleStatus(params);
//       result.fold(
//         (failure) => log('[CircleNotifier] Update failed: ${failure.message}'),
//         (_) => log('[CircleNotifier] Update succeeded'),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _circleSubscription?.cancel();
//     super.dispose();
//   }
// }

// final circleProvider =
//     StateNotifierProvider<CircleNotifier, CircleState>((ref) {
//   return CircleNotifier(
//     createCircle: sl<CreateCircle>(),
//     joinCircle: sl<JoinCircle>(),
//     getCircleStreamForUser: sl<GetCircleStreamForUser>(),
//     updateCircleStatus: sl<UpdateCircleStatus>(),
//     // firebaseAuth: sl<FirebaseAuth>(), // Eliminado porque no se usa
//   );
// });
