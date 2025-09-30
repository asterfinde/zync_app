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
      log("[CircleNotifier] _listenToCircleChanges: No userId, setting NoCircle state");
      state = NoCircle();
      return;
    }

    log("[CircleNotifier] _listenToCircleChanges: Iniciando stream para userId: $_userId");
    state = CircleLoading();
    _circleSubscription?.cancel();
    
    // CORRECCIÓN: Ahora que el UseCase devuelve un Stream, esta es la forma correcta de consumirlo.
    _circleSubscription =
        _getCircleStreamForUser(Params(_userId!)).listen(
      (either) {
        log("[CircleNotifier] Stream evento recibido");
        either.fold(
          (failure) {
            log("[CircleNotifier] Stream error: ${failure.message}");
            state = CircleError(failure.message);
          },
          (circle) {
            if (circle != null) {
              log("[CircleNotifier] ✅ Circle cargado desde stream: ${circle.name}");
              state = CircleLoaded(circle);
            } else {
              log("[CircleNotifier] Stream devolvió null, setting NoCircle state");
              state = NoCircle();
            }
          },
        );
      },
      onError: (e) {
        log("[CircleNotifier] Stream onError: $e");
        state = CircleError(e.toString());
      },
    );
  }

  Future<void> createCircle(String name) async {
    log("[CircleNotifier] createCircle iniciado con nombre: '$name'");
    
    // Mostrar estado de carga
    state = CircleLoading();
    
    final result = await _createCircle(CreateCircleParams(name: name));
    result.fold(
      (failure) {
        log("[CircleNotifier] Creación fallida: ${failure.message}");
        state = CircleError(failure.message);
      },
      (_) {
        log("[CircleNotifier] Creación exitosa. Esperando que el stream detecte el cambio...");
        // El stream se encargará de actualizar el estado cuando detecte el cambio
        // Reiniciar el stream para forzar la detección del cambio
        log("[CircleNotifier] Reiniciando stream para detectar el nuevo círculo...");
        _listenToCircleChanges();
        
        // Si no se actualiza en 10 segundos, hay un problema con el stream
        Timer(const Duration(seconds: 10), () {
          if (state is CircleLoading) {
            log("[CircleNotifier] TIMEOUT: El stream no detectó el cambio del círculo");
            state = CircleError("Stream timeout: Circle created but UI not updated");
          }
        });
      },
    );
  }

  Future<void> joinCircle(String invitationCode) async {
    log("[CircleNotifier] joinCircle llamado con código: '$invitationCode'");
    
    final result = await _joinCircle(JoinCircleParams(invitationCode: invitationCode));
    result.fold(
      (failure) => log("[CircleNotifier] Unión fallida: ${failure.message}"),
      (_) => log("[CircleNotifier] Unión exitosa. Stream actualizará la UI."),
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