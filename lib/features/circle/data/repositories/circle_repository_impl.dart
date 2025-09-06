// lib/features/circle/data/repositories/circle_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/circle.dart';
import '../../domain/entities/user_status.dart';
import '../../domain/repositories/circle_repository.dart';
import '../datasources/circle_remote_data_source.dart';

class CircleRepositoryImpl implements CircleRepository {
  final CircleRemoteDataSource remoteDataSource;
  final FirebaseAuth firebaseAuth;

  CircleRepositoryImpl({
    required this.remoteDataSource,
    required this.firebaseAuth,
  });

  @override
  Future<Either<Failure, void>> createCircle(String name) async {
    try {
      final String uid = firebaseAuth.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        return Left(ServerFailure(message: 'User not authenticated.'));
      }
      await remoteDataSource.createCircle(name, uid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message ?? 'Unknown server error.'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> joinCircle(String invitationCode) async {
    try {
      final String uid = firebaseAuth.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        return Left(ServerFailure(message: 'User not authenticated.'));
      }
      await remoteDataSource.joinCircle(invitationCode, uid);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message ?? 'Unknown server error.'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<Either<Failure, Circle?>> getCircleStreamForUser() {
    final String uid = firebaseAuth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return Stream.value(Left(ServerFailure(message: 'User not authenticated.')));
    }
    return remoteDataSource
        .getCircleStreamForUser(uid)
        .map<Either<Failure, Circle?>>((circleModel) => Right(circleModel));
  }

  @override
  Future<Either<Failure, void>> sendUserStatus({
    required String circleId,
    required StatusType statusType,
    Coordinates? coordinates,
  }) async {
    try {
      final String uid = firebaseAuth.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        return Left(ServerFailure(message: 'User not authenticated.'));
      }
      await remoteDataSource.sendUserStatus(
        circleId: circleId,
        userId: uid,
        statusType: statusType,
        coordinates: coordinates,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message ?? 'Unknown server error.'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Circle>> getCircleByCreatorId(String creatorId) async {
    try {
      final circleModel = await remoteDataSource.getCircleByCreatorId(creatorId);
      return Right(circleModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message ?? 'Unknown server error.'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}