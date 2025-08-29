// lib/features/circle/domain/repositories/circle_repository.dart

import 'package:dartz/dartz.dart';
import 'package:zync_app/core/error/failures.dart';
import 'package:zync_app/features/circle/domain/entities/circle.dart';

abstract class CircleRepository {
  Stream<Either<Failure, Circle?>> getCircleStreamForUser();
  Future<Either<Failure, void>> createCircle(String name);
  Future<Either<Failure, void>> joinCircle(String invitationCode);
  Future<Either<Failure, void>> updateCircleStatus(String circleId, String newStatusEmoji);
}