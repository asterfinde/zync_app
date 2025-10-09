// lib/features/circle/domain/usecases/send_user_status.dart

import 'dart:developer'; // AÑADIDO: Import para logging.
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:zync_app/core/error/failures.dart';
import 'package:zync_app/core/usecases/usecase.dart';
import 'package:zync_app/features/circle/domain/entities/user_status.dart';
import 'package:zync_app/features/circle/domain/repositories/circle_repository.dart';
import 'package:zync_app/features/circle/domain/services/geolocation_service.dart';

class SendUserStatus implements UseCase<void, SendUserStatusParams> {
  final CircleRepository repository;
  final GeolocationService geolocationService;

  SendUserStatus(this.repository, this.geolocationService);

  @override
  Future<Either<Failure, void>> call(SendUserStatusParams params) async {
    // --- PUNTO DE TRAZA 4 ---
    log('[TRAZA 4/5] UseCase: Método "call" invocado. Parámetros: circleId=${params.circleId}, status=${params.statusType.name}');
    
    Coordinates? coordinatesToBeSent = params.coordinates;

    // Si en el futuro algún estado requiere coordenadas, agregar aquí la lógica
    return await repository.sendUserStatus(
      circleId: params.circleId,
      statusType: params.statusType,
      coordinates: coordinatesToBeSent,
    );
  }
}

class SendUserStatusParams extends Equatable {
  final String circleId;
  final StatusType statusType;
  final Coordinates? coordinates;

  const SendUserStatusParams({
    required this.circleId,
    required this.statusType,
    this.coordinates,
  });

  @override
  List<Object?> get props => [circleId, statusType, coordinates];
}
