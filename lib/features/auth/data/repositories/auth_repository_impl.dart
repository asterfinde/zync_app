// lib/features/auth/data/repositories/auth_repository_impl.dart

import 'dart:developer'; // Añadido para logging
import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, User>> signInOrRegister({
    required String email,
    required String password,
  }) async {
    log('[AuthRepository] HU: Verificando conexión a internet...');
    if (await networkInfo.isConnected) {
      try {
        log('[AuthRepository] HU: Hay conexión. Llamando a remoteDataSource.signInOrRegister...');
        final remoteUser = await remoteDataSource.signInOrRegister(
          email: email,
          password: password,
        );
        log('[AuthRepository] HU: remoteDataSource devolvió el usuario con UID: ${remoteUser.uid}, email: ${remoteUser.email}');
        await localDataSource.cacheUser(remoteUser);
        log('[AuthRepository] HU: Usuario cacheado con UID: ${remoteUser.uid}');
        await localDataSource.cacheUser(remoteUser);
        return Right(remoteUser);
      } on ServerException catch (e) {
        log('[AuthRepository] HU: ServerException atrapada: ${e.toString()}');
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      log('[AuthRepository] HU: No hay conexión a internet.');
      return Left(NetworkFailure(message: 'No internet connection.'));
    }
  }

  // El resto del archivo no necesita logs para este caso de prueba.
  // ...
  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final localUser = await localDataSource.getLastUser();
      log('[AuthRepository] HU: Usuario obtenido del caché: ${localUser?.uid}, email: ${localUser?.email}');
      return Right(localUser);
      // ignore: empty_catches
    } on CacheException {}

    if (await networkInfo.isConnected) {
      try {
        final remoteUser = await remoteDataSource.getCurrentUser();
        log('[AuthRepository] HU: Usuario obtenido de remoto: ${remoteUser?.uid}, email: ${remoteUser?.email}');
        if (remoteUser != null) {
          await localDataSource.cacheUser(remoteUser);
          log('[AuthRepository] HU: Usuario cacheado con UID: ${remoteUser.uid}');
          return Right(remoteUser);
        } else {
          log('[AuthRepository] HU: No hay usuario autenticado en remoto.');
          return Left(ServerFailure(message: 'No authenticated user found.'));
        }
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No internet connection.'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.signOut();
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(
          NetworkFailure(message: 'No internet connection to sign out.'));
    }
  }
}

// // lib/features/auth/data/repositories/auth_repository_impl.dart

// import 'package:dartz/dartz.dart';

// import '../../../../core/error/exceptions.dart';
// import '../../../../core/error/failures.dart';
// import '../../../../core/network/network_info.dart';
// import '../../domain/entities/user.dart';
// import '../../domain/repositories/auth_repository.dart';
// import '../datasources/auth_local_data_source.dart';
// import '../datasources/auth_remote_data_source.dart';

// class AuthRepositoryImpl implements AuthRepository {
//   final AuthRemoteDataSource remoteDataSource;
//   final AuthLocalDataSource localDataSource;
//   final NetworkInfo networkInfo;

//   AuthRepositoryImpl({
//     required this.remoteDataSource,
//     required this.localDataSource,
//     required this.networkInfo,
//   });

//   @override
//   Future<Either<Failure, User>> signInOrRegister({
//     required String email,
//     required String password,
//   }) async {
//     if (await networkInfo.isConnected) {
//       try {
//         final remoteUser = await remoteDataSource.signInOrRegister(
//           email: email,
//           password: password,
//         );
//         // Asumiendo que signInOrRegister nunca retorna null en caso de éxito
//         await localDataSource.cacheUser(remoteUser);
//         return Right(remoteUser);
//       } on ServerException catch (e) {
//         return Left(ServerFailure(message: e.toString())); // Usamos toString para más detalle
//       }
//     } else {
//       // Corregido: Se añade un mensaje a NetworkFailure
//       return Left(NetworkFailure(message: 'No internet connection.'));
//     }
//   }

//   @override
//   Future<Either<Failure, User?>> getCurrentUser() async {
//     // Primero intentar desde el caché, es más rápido.
//     try {
//       final localUser = await localDataSource.getLastUser();
//       return Right(localUser);
//     } on CacheException {
//       // Si falla el caché, no es un error fatal, procedemos a la red.
//     }

//     if (await networkInfo.isConnected) {
//       try {
//         final remoteUser = await remoteDataSource.getCurrentUser();
//         if (remoteUser != null) {
//           await localDataSource.cacheUser(remoteUser);
//         }
//         return Right(remoteUser);
//       } on ServerException catch (e) {
//         return Left(ServerFailure(message: e.toString()));
//       }
//     } else {
//       // Si no hay caché ni red, es un fallo de red.
//       // Corregido: Se añade un mensaje a NetworkFailure
//       return Left(NetworkFailure(message: 'No internet connection.'));
//     }
//   }

//   @override
//   Future<Either<Failure, void>> signOut() async {
//     if (await networkInfo.isConnected) {
//       try {
//         await remoteDataSource.signOut();
//         // Podríamos también limpiar el caché local aquí si quisiéramos
//         // await localDataSource.clearUser();
//         return const Right(null);
//       } on ServerException catch (e) {
//         return Left(ServerFailure(message: e.toString()));
//       }
//     } else {
//       // Corregido: Se añade un mensaje a NetworkFailure
//       return Left(NetworkFailure(message: 'No internet connection to sign out.'));
//     }
//   }
// }
