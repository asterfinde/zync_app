import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class FakePresencePublisher implements PresencePublisher {
  Result<Unit> publishResult = Success(Unit.instance);
  int publishCallCount = 0;
  PresenceState? lastPublishedState;
  String? lastUserId;
  String? lastCircleId;

  @override
  Future<Result<Unit>> publish({
    required PresenceState state,
    required String userId,
    required String circleId,
  }) async {
    publishCallCount++;
    lastPublishedState = state;
    lastUserId   = userId;
    lastCircleId = circleId;
    return publishResult;
  }
}
