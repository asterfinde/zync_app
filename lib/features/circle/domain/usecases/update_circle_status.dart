import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/circle_repository.dart';

class UpdateCircleStatus implements UseCase<void, UpdateCircleStatusParams> {
  final CircleRepository repository;

  UpdateCircleStatus(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateCircleStatusParams params) async {
    return await repository.updateCircleStatus(params.circleId, params.newStatus);
  }
}

class UpdateCircleStatusParams extends Equatable {
  final String circleId;
  final String newStatus;

  const UpdateCircleStatusParams({required this.circleId, required this.newStatus});

  @override
  List<Object?> get props => [circleId, newStatus];
}
