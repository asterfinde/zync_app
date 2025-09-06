// lib/features/circle/domain/usecases/send_user_status.dart

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
    Coordinates? coordinatesToBeSent = params.coordinates;

    if (params.statusType == StatusType.location || params.statusType == StatusType.sos) {
      final locationResult = await geolocationService.getCurrentPosition();

      // Si falla la geolocalización, devolvemos el error tal cual.
      return locationResult.fold(
        (failure) => Left(failure),
        (position) async {
          coordinatesToBeSent = Coordinates(
            latitude: position.latitude,
            longitude: position.longitude,
          );
          return await repository.sendUserStatus(
            circleId: params.circleId,
            statusType: params.statusType,
            coordinates: coordinatesToBeSent,
          );
        },
      );
    } else {
      // Estados que no requieren ubicación.
      return await repository.sendUserStatus(
        circleId: params.circleId,
        statusType: params.statusType,
        coordinates: coordinatesToBeSent,
      );
    }
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

// import 'package:dartz/dartz.dart';
// import 'package:equatable/equatable.dart';
// // --- CORRECCIÓN DE IMPORTS ---
// import 'package:zync_app/core/error/failures.dart';
// import 'package:zync_app/core/usecases/usecase.dart';
// import 'package:zync_app/features/circle/domain/entities/user_status.dart';
// import 'package:zync_app/features/circle/domain/repositories/circle_repository.dart';
// import 'package:zync_app/features/circle/domain/services/geolocation_service.dart';
// // --- FIN DE LA CORRECCIÓN ---


// class SendUserStatus implements UseCase<void, SendUserStatusParams> {
//   final CircleRepository repository;
//   final GeolocationService geolocationService;

//   SendUserStatus(this.repository, this.geolocationService);

//   @override
//   Future<Either<Failure, void>> call(SendUserStatusParams params) async {
    
//     Coordinates? coordinatesToBeSent = params.coordinates;

//     if (params.statusType == StatusType.location || params.statusType == StatusType.sos) {
      
//       final locationResult = await geolocationService.getCurrentPosition();

//       // --- LÓGICA DE EITHER CORREGIDA ---
//       // Usamos .fold() que es la forma más segura de manejar un Either.
//       // Si es Left (un Failure), lo retornamos inmediatamente.
//       // Si es Right (un Position), continuamos y asignamos las coordenadas.
//       return locationResult.fold(
//         (failure) {
//           // Inmediatamente detenemos y devolvemos el error de geolocalización.
//           return Left(failure);
//         },
//         (position) async {
//           // El bloque 'Right' continúa la ejecución.
//           coordinatesToBeSent = Coordinates(latitude: position.latitude, longitude: position.longitude);
//           // Ahora llamamos al repositorio con las nuevas coordenadas.
//           return await repository.sendUserStatus(
//             circleId: params.circleId,
//             statusType: params.statusType,
//             coordinates: coordinatesToBeSent,
//           );
//         },
//       );
//     } else {
//       // Si no se necesita ubicación, simplemente llamamos al repositorio como antes.
//       return await repository.sendUserStatus(
//         circleId: params.circleId,
//         statusType: params.statusType,
//         coordinates: coordinatesToBeSent,
//       );
//     }
//   }
// }

// class SendUserStatusParams extends Equatable {
//   final String circleId;
//   final StatusType statusType;
//   final Coordinates? coordinates;

//   const SendUserStatusParams({
//     required this.circleId,
//     required this.statusType,
//     this.coordinates,
//   });

//   @override
//   List<Object?> get props => [circleId, statusType, coordinates];
// }