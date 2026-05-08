import 'dart:async';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class FakePresenceRepository implements PresenceRepository {
  PresenceState _state = const Normal(currentId: StatusIds.fine);
  Result<Unit>? saveStateOverride; // null → Success por defecto
  int saveCallCount = 0;
  PresenceState? lastSavedState;

  final _controller = StreamController<PresenceState>.broadcast();

  void setState(PresenceState state) => _state = state;

  @override
  Stream<PresenceState> get stateStream => _controller.stream;

  @override
  Future<Result<PresenceState>> currentState() async => Success(_state);

  @override
  Future<Result<Unit>> saveState(PresenceState state) async {
    saveCallCount++;
    lastSavedState = state;
    final result = saveStateOverride ?? Success(Unit.instance);
    if (result.isSuccess) {
      _state = state;
      _controller.add(state);
    }
    return result;
  }

  void dispose() => _controller.close();
}
