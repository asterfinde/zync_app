// lib/features/auth/domain/usecases/get_current_user.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para obtener el usuario actual.
class GetCurrentUser implements UseCase<User, NoParams> {
  final AuthRepository repository;

  GetCurrentUser(this.repository);

  /// Llama al método del repositorio para obtener el usuario actual.
  @override
  Future<Either<Failure, User>> call(NoParams params) async {
    return await repository.getCurrentUser();
  }
}

// -----------------------------------------------------------------

// features/auth/domain/usecases/sign_in_or_register.dart

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart'; // Necesitarás el paquete equatable
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para iniciar sesión o registrar un usuario.
class SignInOrRegister implements UseCase<User, SignInOrRegisterParams> {
  final AuthRepository repository;

  SignInOrRegister(this.repository);

  /// Llama al método del repositorio para iniciar sesión/registrar.
  @override
  Future<Either<Failure, User>> call(SignInOrRegisterParams params) async {
    return await repository.signInOrRegister(
      email: params.email,
      password: params.password,
    );
  }
}

/// Parámetros necesarios para el caso de uso SignInOrRegister.
class SignInOrRegisterParams extends Equatable {
  final String email;
  final String password;

  const SignInOrRegisterParams({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}


// -----------------------------------------------------------------

// features/auth/domain/usecases/sign_out.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para cerrar sesión.
class SignOut implements UseCase<void, NoParams> {
  final AuthRepository repository;

  SignOut(this.repository);

  /// Llama al método del repositorio para cerrar la sesión.
  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.signOut();
  }
}
