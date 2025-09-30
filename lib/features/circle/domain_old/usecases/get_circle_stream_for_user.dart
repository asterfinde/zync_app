// lib/features/circle/domain/usecases/get_circle_stream_for_user.dart  

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:zync_app/core/error/failures.dart';
import 'package:zync_app/features/circle/domain/entities/circle.dart';
import 'package:zync_app/features/circle/domain/repositories/circle_repository.dart';

class GetCircleStreamForUser {
  final CircleRepository repository;

  GetCircleStreamForUser(this.repository);

  // CORRECCIÓN DEFINITIVA: Se revierte la firma del método 'call' para que coincida
  // con lo que tu Repository realmente devuelve (Stream<Either...>>) y cómo espera
  // ser llamado (sin argumentos), según los errores que has reportado.
  Stream<Either<Failure, Circle?>> call(Params params) {
    return repository.getCircleStreamForUser();
  }
}

// La clase Params se mantiene porque el Provider la usa para llamar a este UseCase.
class Params extends Equatable {
  final String userId;

  const Params(this.userId);

  @override
  List<Object?> get props => [userId];
}