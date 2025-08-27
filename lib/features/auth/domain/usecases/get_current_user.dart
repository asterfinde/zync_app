// lib/features/auth/domain/usecases/get_current_user.dart

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart'; // Asegúrate de que User esté importado
import '../repositories/auth_repository.dart';

class GetCurrentUser implements UseCase<User?, NoParams> { // <-- CAMBIO AQUÍ
  final AuthRepository repository;

  GetCurrentUser(this.repository);

  @override
  Future<Either<Failure, User?>> call(NoParams params) async { // <-- Y AQUÍ
    return await repository.getCurrentUser();
  }
}