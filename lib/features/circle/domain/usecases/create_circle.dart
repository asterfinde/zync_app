import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/circle_repository.dart';

class CreateCircle implements UseCase<void, CreateCircleParams> {
  final CircleRepository repository;

  CreateCircle(this.repository);

  @override
  Future<Either<Failure, void>> call(CreateCircleParams params) async {
    return await repository.createCircle(params.name);
  }
}

class CreateCircleParams extends Equatable {
  final String name;

  const CreateCircleParams({required this.name});

  @override
  List<Object?> get props => [name];
}
