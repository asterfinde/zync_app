// lib/features/circle/presentation/provider/circle_provider.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
import 'package:zync_app/core/di/injection_container.dart';
import 'package:zync_app/features/circle/domain/entities/user_status.dart';
import 'package:zync_app/features/circle/domain/usecases/create_circle.dart';
import 'package:zync_app/features/circle/domain/usecases/get_circle_stream_for_user.dart';
import 'package:zync_app/features/circle/domain/usecases/join_circle.dart';
import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
import 'circle_state.dart';

class CircleNotifier extends StateNotifier<CircleState> {
  final CreateCircle _createCircle;
  final JoinCircle _joinCircle; // FUNCIONALIDAD RESTAURADA
  final GetCircleStreamForUser _getCircleStreamForUser;
  final SendUserStatus _sendUserStatus; // FUNCIONALIDAD RESTAURADA
  final String? _userId;

  StreamSubscription? _circleSubscription;

  CircleNotifier({
    required CreateCircle createCircle,
    required JoinCircle joinCircle, // FUNCIONALIDAD RESTAURADA
    required GetCircleStreamForUser getCircleStreamForUser,
    required SendUserStatus sendUserStatus, // FUNCIONALIDAD RESTAURADA
    required String? userId,
  })  : _createCircle = createCircle,
        _joinCircle = joinCircle, // FUNCIONALIDAD RESTAURADA
        _getCircleStreamForUser = getCircleStreamForUser,
        _sendUserStatus = sendUserStatus, // FUNCIONALIDAD RESTAURADA
        _userId = userId,
        super(CircleInitial()) {
    _listenToCircleChanges();
  }
  
  void _listenToCircleChanges() {
    if (_userId == null) {
      state = NoCircle();
      return;
    }

    state = CircleLoading();
    _circleSubscription?.cancel();
    
    // CORRECCIÓN: Ahora que el UseCase devuelve un Stream, esta es la forma correcta de consumirlo.
    _circleSubscription =
        _getCircleStreamForUser(Params(_userId!)).listen(
      (either) {
        either.fold(
          (failure) {
            state = CircleError(failure.message);
          },
          (circle) {
            if (circle != null) {
              state = CircleLoaded(circle);
            } else {
              state = NoCircle();
            }
          },
        );
      },
      onError: (e) {
        state = CircleError(e.toString());
      },
    );
  }

  Future<void> createCircle(String name) async {
    final result = await _createCircle(CreateCircleParams(name: name));
    result.fold(
      (failure) => log("Creación fallida: ${failure.message}"),
      (_) => log("Creación exitosa. Stream actualizará la UI."),
    );
  }

  Future<void> joinCircle(String invitationCode) async {
    final result = await _joinCircle(JoinCircleParams(invitationCode: invitationCode));
     result.fold(
      (failure) => log("Unión fallida: ${failure.message}"),
      (_) => log("Unión exitosa. Stream actualizará la UI."),
    );
  }

  // FUNCIONALIDAD RESTAURADA: Este método es requerido por in_circle_view.dart
  Future<void> sendUserStatus(StatusType statusType,
      {Coordinates? coordinates}) async {
    if (state is CircleLoaded) {
      final circleId = (state as CircleLoaded).circle.id;
      final params = SendUserStatusParams(
        circleId: circleId,
        statusType: statusType,
        coordinates: coordinates,
      );
      await _sendUserStatus(params);
    }
  }

  @override
  void dispose() {
    _circleSubscription?.cancel();
    super.dispose();
  }
}

final circleProvider = StateNotifierProvider<CircleNotifier, CircleState>((ref) {
  final authState = ref.watch(authProvider);
  final userId = (authState is Authenticated) ? authState.user.uid : null;
  
  return CircleNotifier(
    createCircle: sl<CreateCircle>(),
    joinCircle: sl<JoinCircle>(), // FUNCIONALIDAD RESTAURADA
    getCircleStreamForUser: sl<GetCircleStreamForUser>(),
    sendUserStatus: sl<SendUserStatus>(), // FUNCIONALIDAD RESTAURADA
    userId: userId,
  );
});