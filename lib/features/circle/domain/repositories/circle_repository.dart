// lib/features/circle/domain/repositories/circle_repository.dart

import 'package:dartz/dartz.dart';
import 'package:zync_app/core/error/failures.dart';
import 'package:zync_app/features/circle/domain/entities/circle.dart';
// ¡IMPORTANTE! Importamos nuestras entidades de estado
import 'package:zync_app/features/circle/domain/entities/user_status.dart';

abstract class CircleRepository {
  Stream<Either<Failure, Circle?>> getCircleStreamForUser();
  Future<Either<Failure, void>> createCircle(String name);
  Future<Either<Failure, void>> joinCircle(String invitationCode);
  
  // 1. ELIMINAMOS el método antiguo y obsoleto 'updateCircleStatus'.
  // Future<Either<Failure, void>> updateCircleStatus(String circleId, String newStatusEmoji);

  // 2. AÑADIMOS la firma del nuevo método.
  //    Ahora el UseCase y el Repositorio "hablan el mismo idioma".
  Future<Either<Failure, void>> sendUserStatus({
    required String circleId,
    required StatusType statusType,
    Coordinates? coordinates,
  });

  Future<Either<Failure, Circle>> getCircleByCreatorId(String creatorId);
}

