// lib/features/auth/data/repositories/auth_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart'; // (Aún por crear)
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

/// Implementación del contrato AuthRepository.
/// Esta clase es el punto de unión entre la capa de dominio y la capa de datos.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo; // Para verificar la conexión a internet

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
    if (await networkInfo.isConnected) {
      try {
        final remoteUser = await remoteDataSource.signInOrRegister(
          email: email,
          password: password,
        );
        // Guardamos el usuario en caché después de un inicio de sesión exitoso
        await localDataSource.cacheUser(remoteUser);
        return Right(remoteUser);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    // Primero intentamos obtener el usuario de la caché
    try {
      final localUser = await localDataSource.getLastUser();
      if (localUser != null) {
        return Right(localUser);
      }
    } on CacheException {
      // Si falla la caché, no es crítico, podemos seguir a la fuente remota.
    }

    // Si no está en caché o falló, vamos a la fuente remota
    if (await networkInfo.isConnected) {
      try {
        final remoteUser = await remoteDataSource.getCurrentUser();
        if (remoteUser != null) {
          await localDataSource.cacheUser(remoteUser);
          return Right(remoteUser);
        } else {
          // No hay usuario en sesión remota
          return Left(ServerFailure(message: 'No user signed in.'));
        }
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      // No hay conexión y no se encontró en caché
      return Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.signOut();
        // Podríamos también limpiar la caché aquí si fuera necesario
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return Left(NetworkFailure());
    }
  }
}
