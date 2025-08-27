// lib/features/auth/data/repositories/auth_repository_impl.dart

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
    if (await networkInfo.isConnected) {
      try {
        final remoteUser = await remoteDataSource.signInOrRegister(
          email: email,
          password: password,
        );
        await localDataSource.cacheUser(remoteUser);
        return Right(remoteUser);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      // Esta línea ya es correcta y satisface el warning de la línea 41
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final localUser = await localDataSource.getLastUser();
      return Right(localUser);
    } on CacheException {
      // Ignorar, intentaremos con la red.
    }

    if (await networkInfo.isConnected) {
      try {
        final remoteUser = await remoteDataSource.getCurrentUser();
        if (remoteUser != null) {
          await localDataSource.cacheUser(remoteUser);
        }
        return Right(remoteUser);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      // Esta línea ya es correcta y satisface el warning de la línea 65
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.signOut();
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      // Esta línea ya es correcta y satisface el warning de la línea 79
      return const Left(NetworkFailure());
    }
  }
}