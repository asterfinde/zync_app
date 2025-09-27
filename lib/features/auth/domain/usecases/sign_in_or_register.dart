import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignInOrRegister implements UseCase<User, SignInOrRegisterParams> {
  final AuthRepository repository;

  SignInOrRegister(this.repository);

  @override
  Future<Either<Failure, User>> call(SignInOrRegisterParams params) async {
    return await repository.signInOrRegister(
      email: params.email,
      password: params.password,
      nickname: params.nickname,
    );
  }
}

class SignInOrRegisterParams extends Equatable {
  final String email;
  final String password;
  final String nickname;

  const SignInOrRegisterParams({required this.email, required this.password, this.nickname = ''});

  @override
  List<Object> get props => [email, password, nickname];
}