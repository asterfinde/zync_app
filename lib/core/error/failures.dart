// lib/core/error/failures.dart

import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  // Si tienes propiedades aquí, asegúrate de que el constructor sea const.
  const Failure([List properties = const <dynamic>[]]);
  
  @override
  List<Object> get props => []; // Puedes dejar la lista vacía si no hay props.
}

// Clases de fallos específicos
class ServerFailure extends Failure {
  final String? message;

  // --- AÑADE 'const' AQUÍ ---
  const ServerFailure({this.message});
}

class NetworkFailure extends Failure {
  // --- AÑADE 'const' AQUÍ ---
  const NetworkFailure();
}

class CacheFailure extends Failure {
  // --- AÑADE 'const' AQUÍ ---
  const CacheFailure();
}