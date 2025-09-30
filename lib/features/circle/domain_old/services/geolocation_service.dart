// lib/features/circle/domain/services/geolocation_service.dart

import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zync_app/core/error/failures.dart';

abstract class GeolocationService {
  /// Obtiene la ubicación actual del dispositivo.
  /// Maneja la solicitud de permisos internamente.
  /// Devuelve un [PermissionFailure] si los permisos son denegados.
  /// Devuelve un [ServerFailure] si ocurre otro error.
  Future<Either<Failure, Position>> getCurrentPosition();
}