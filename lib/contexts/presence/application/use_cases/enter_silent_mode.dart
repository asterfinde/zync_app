import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class EnterSilentMode {
  final PresenceRepository _repository;

  EnterSilentMode({required PresenceRepository repository})
      : _repository = repository;

  Future<Result<Unit>> call({required String userId}) async {
    Contract.requires(userId.isNotEmpty, 'userId debe ser no vacío');

    final currentResult = await _repository.currentState();
    if (currentResult.isFailure) return currentResult as Result<Unit>;
    final current = currentResult.valueOrNull!;

    // Guardia de idempotencia: ya está en Silent Mode, nada que hacer.
    if (current is SilentMode) return Success(Unit.instance);

    // Pre-silencio = último estado manual, o current si no hay manual.
    // postcondición implícita: saveState(SilentMode(...)) garantiza
    // que SharedPrefs quedará en SilentMode si devuelve Success.
    final preSilentId = switch (current) {
      Normal(:final lastManualId, :final currentId) =>
          lastManualId ?? currentId,
      _ => StatusIds.fine,
    };

    return _repository.saveState(SilentMode(
      preSilentId: preSilentId,
      enteredAt:   DateTime.now(),
    ));
  }
}
