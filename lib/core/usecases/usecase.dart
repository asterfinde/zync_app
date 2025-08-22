// core/usecases/usecase.dart

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../error/failures.dart';

/// Clase base abstracta para los casos de uso.
/// Define una firma estándar para todos los casos de uso de la aplicación.
/// [Type] es el tipo de dato que el caso de uso devolverá en caso de éxito.
/// [Params] es el tipo de los parámetros que el caso de uso necesita para ejecutarse.
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Un objeto para ser usado cuando un caso de uso no requiere parámetros.
class NoParams extends Equatable {
  @override
  List<Object> get props => [];
}
