import 'dart:async';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';
import 'package:nunakin_app/platform/persistence/native_keys.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class SharedPrefsPresenceRepository implements PresenceRepository {
  final KvStore _kv;
  final _stateController = StreamController<PresenceState>.broadcast();

  SharedPrefsPresenceRepository(this._kv);

  @override
  Stream<PresenceState> get stateStream => _stateController.stream;

  @override
  Future<Result<PresenceState>> currentState() async {
    try {
      final isSilent = await _kv.getBool(NativeSharedKeys.isSilentModeActive) ?? false;
      if (isSilent) {
        final preSilentId = await _kv.getString(NativeSharedKeys.preSilentStatusId);
        final enteredAtMs = await _kv.getInt(NativeSharedKeys.silentEnteredAt);
        final enteredAt = enteredAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(enteredAtMs)
            : DateTime.now(); // fallback: activado antes de Sem 2
        return Success(SilentMode(
          preSilentId: preSilentId ?? StatusIds.fine,
          enteredAt: enteredAt,
        ));
      }
      final currentId    = await _kv.getString(NativeSharedKeys.currentStatusId);
      final lastManualId = await _kv.getString(NativeSharedKeys.manualStatusId);
      return Success(Normal(
        currentId:    currentId    ?? StatusIds.fine,
        lastManualId: lastManualId,
      ));
    } catch (e, st) {
      return FailureResult(UnexpectedFailure(
        message: 'Error leyendo estado de presencia: $e',
        cause: e,
        stackTrace: st,
      ));
    }
  }

  @override
  Future<Result<Unit>> saveState(PresenceState state) async {
    try {
      switch (state) {
        case Normal(:final currentId, :final lastManualId):
          await _kv.setString(NativeSharedKeys.currentStatusId, currentId);
          if (lastManualId != null) {
            await _kv.setString(NativeSharedKeys.manualStatusId, lastManualId);
          }
          await _kv.remove(NativeSharedKeys.isSilentModeActive);
          await _kv.remove(NativeSharedKeys.preSilentStatusId);
          await _kv.remove(NativeSharedKeys.silentEnteredAt);

        case SilentMode(:final preSilentId, :final enteredAt):
          await _kv.setBool(NativeSharedKeys.isSilentModeActive, true);
          await _kv.setString(NativeSharedKeys.preSilentStatusId, preSilentId);
          await _kv.setInt(
            NativeSharedKeys.silentEnteredAt,
            enteredAt.millisecondsSinceEpoch,
          );

        case BackgroundNotificationActive(:final notifStatusId):
          await _kv.setString(NativeSharedKeys.currentStatusId, notifStatusId);

        case SOSActive():
          await _kv.setString(NativeSharedKeys.currentStatusId, StatusIds.sos);
      }
      _stateController.add(state);
      return Success(Unit.instance);
    } catch (e, st) {
      return FailureResult(UnexpectedFailure(
        message: 'Error guardando estado de presencia: $e',
        cause: e,
        stackTrace: st,
      ));
    }
  }

  void dispose() => _stateController.close();
}
