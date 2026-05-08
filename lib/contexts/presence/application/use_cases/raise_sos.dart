import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class RaiseSOS {
  final PresenceRepository _repository;
  final PresencePublisher  _publisher;

  RaiseSOS({
    required PresenceRepository repository,
    required PresencePublisher  publisher,
  })  : _repository = repository,
        _publisher  = publisher;

  Future<Result<Unit>> call({
    required String userId,
    required String circleId,
    required double latitude,
    required double longitude,
  }) async {
    Contract.requires(userId.isNotEmpty,   'userId debe ser no vacío');
    Contract.requires(circleId.isNotEmpty, 'circleId debe ser no vacío');

    final currentResult = await _repository.currentState();
    if (currentResult.isFailure) return currentResult as Result<Unit>;
    final previousId = currentResult.valueOrNull!.visibleStatusId;

    final sosState = SOSActive(
      previousId: previousId,
      latitude:   latitude,
      longitude:  longitude,
    );

    final saveResult = await _repository.saveState(sosState);
    if (saveResult.isFailure) return saveResult;

    return _publisher.publish(
      state:    sosState,
      userId:   userId,
      circleId: circleId,
    );
  }
}
