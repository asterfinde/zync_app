import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class SetManualStatus {
  final PresenceRepository _repository;
  final PresencePublisher  _publisher;

  SetManualStatus({
    required PresenceRepository repository,
    required PresencePublisher  publisher,
  })  : _repository = repository,
        _publisher  = publisher;

  Future<Result<Unit>> call({
    required String statusId,
    required String userId,
    required String circleId,
  }) async {
    Contract.requires(statusId.isNotEmpty,  'statusId debe ser no vacío');
    Contract.requires(userId.isNotEmpty,    'userId debe ser no vacío');
    Contract.requires(circleId.isNotEmpty,  'circleId debe ser no vacío');

    final newState = Normal(currentId: statusId, lastManualId: statusId);

    final saveResult = await _repository.saveState(newState);
    if (saveResult.isFailure) return saveResult;

    return _publisher.publish(
      state:    newState,
      userId:   userId,
      circleId: circleId,
    );
  }
}
