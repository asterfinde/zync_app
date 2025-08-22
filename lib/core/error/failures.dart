// core/error/failures.dart

import 'package:equatable/equatable.dart';

/// Clase base abstracta para los errores (Failures).
/// En Arquitectura Limpia, los errores de las capas externas (Data, Presentation)
/// se convierten en un Failure para ser manejados de forma consistente.
abstract class Failure extends Equatable {
  // Si se usan propiedades, se deben pasar al constructor.
  const Failure([List properties = const <dynamic>[]]);

  @override
  List<Object> get props => [];
}

// Failures generales de la aplicación

/// Se produce cuando hay un error en el servidor (ej. API, base de datos remota).
class ServerFailure extends Failure {
  final String? message;
  const ServerFailure({this.message});
}

/// Se produce cuando hay un error con la caché local.
class CacheFailure extends Failure {
  final String? message;
  const CacheFailure({this.message});
}

/// Se produce cuando no hay conexión a internet.
class NetworkFailure extends Failure {}
