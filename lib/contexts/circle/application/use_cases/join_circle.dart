import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class JoinCircle {
  final CircleRepository _repository;

  JoinCircle({required CircleRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call(String invitationCode) async {
    Contract.requires(
      invitationCode.isNotEmpty,
      'invitationCode must not be empty',
    );
    return _repository.requestToJoin(invitationCode);
  }
}
