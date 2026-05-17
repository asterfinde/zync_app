import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class DeleteAccount {
  final CircleRepository _repository;

  DeleteAccount({required CircleRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call() => _repository.deleteAccount();
}
