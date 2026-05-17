import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class ApproveJoinRequest {
  final CircleRepository _repository;

  ApproveJoinRequest({required CircleRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call({
    required String circleId,
    required String requestingUserId,
  }) async {
    Contract.requires(circleId.isNotEmpty, 'circleId must not be empty');
    Contract.requires(
      requestingUserId.isNotEmpty,
      'requestingUserId must not be empty',
    );
    return _repository.approveJoin(
      circleId: circleId,
      requestingUserId: requestingUserId,
    );
  }
}
