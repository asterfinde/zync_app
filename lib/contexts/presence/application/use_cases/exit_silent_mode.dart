import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class ExitSilentMode {
  final PresenceRepository _repository;

  ExitSilentMode({required PresenceRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call({required String userId}) async {
    Contract.requires(userId.isNotEmpty, 'userId debe ser no vacío');

    final currentResult = await _repository.currentState();
    if (currentResult.isFailure) return currentResult as Result<Unit>;
    final current = currentResult.valueOrNull!;

    // Idempotencia: ya está en Normal, nada que hacer.
    if (current is Normal) return Success(Unit.instance);

    final restoredId = switch (current) {
      SilentMode(:final preSilentId) => preSilentId,
      _                              => StatusIds.fine,
    };

    // postcondición implícita: saveState(Normal(...)) garantiza
    // que SharedPrefs quedará en Normal si devuelve Success.
    return _repository.saveState(Normal(
      currentId:    restoredId,
      lastManualId: restoredId,
    ));
  }
}
