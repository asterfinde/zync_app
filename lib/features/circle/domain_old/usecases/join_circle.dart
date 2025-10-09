import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/circle_repository.dart';

class JoinCircle implements UseCase<void, JoinCircleParams> {
  final CircleRepository repository;

  JoinCircle(this.repository);

  @override
  Future<Either<Failure, void>> call(JoinCircleParams params) async {
    return await repository.joinCircle(params.invitationCode);
  }
}

class JoinCircleParams extends Equatable {
  final String invitationCode;

  const JoinCircleParams({required this.invitationCode});

  @override
  List<Object?> get props => [invitationCode];
}
