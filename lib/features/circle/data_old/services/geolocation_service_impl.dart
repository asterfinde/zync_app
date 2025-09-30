// lib/features/circle/data/services/geolocation_service_impl.dart

import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zync_app/core/error/failures.dart';
import 'package:zync_app/features/circle/domain/services/geolocation_service.dart';

class GeolocationServiceImpl implements GeolocationService {

  @override
  Future<Either<Failure, Position>> getCurrentPosition() async {
    try {
      // 1. Comprobar si los servicios de ubicación están habilitados.
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const Left(PermissionFailure(message: 'Los servicios de ubicación están deshabilitados.'));
      }

      // 2. Comprobar el estado de los permisos actuales.
      LocationPermission permission = await Geolocator.checkPermission();
      
      // 3. Si los permisos están denegados, solicitarlos.
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const Left(PermissionFailure(message: 'Los permisos de ubicación fueron denegados.'));
        }
      }
      
      // 4. Si los permisos están denegados permanentemente, no podemos hacer nada.
      if (permission == LocationPermission.deniedForever) {
        return const Left(PermissionFailure(message: 'Los permisos de ubicación están denegados permanentemente. No podemos solicitar permisos.'));
      } 
      
      // 5. Si llegamos aquí, los permisos están concedidos. Obtenemos la ubicación.
      return Right(await Geolocator.getCurrentPosition());

    } catch (e) {
      return Left(ServerFailure(message: 'Error al obtener la ubicación: ${e.toString()}'));
    }
  }
}