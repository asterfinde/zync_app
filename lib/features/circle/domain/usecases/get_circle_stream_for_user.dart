// lib/features/circle/domain/usecases/get_circle_stream_for_user.dart  

import 'package:dartz/dartz.dart';
import 'package:zync_app/core/error/failures.dart';
import 'package:zync_app/features/circle/domain/entities/circle.dart';
import 'package:zync_app/features/circle/domain/repositories/circle_repository.dart';

// Clase simple para parámetros vacíos si no existe NoParams
class GetCircleStreamParams {
  final String? userId; // Opcional si se obtiene del auth
  
  const GetCircleStreamParams({this.userId});
}

class GetCircleStreamForUser {
  final CircleRepository repository;

  GetCircleStreamForUser(this.repository);

  // Método que devuelve un Stream directamente
  Stream<Either<Failure, Circle?>> call([GetCircleStreamParams? params]) {
    // El repositorio obtiene el ID del estado de auth internamente
    return repository.getCircleStreamForUser();
  }
}