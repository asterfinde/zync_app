import 'dart:async';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';

/// Expone el estado de presencia como stream para la capa de presentación.
///
/// No se conecta a la UI todavía — la conexión ocurre en Sem 5 cuando
/// InCircleView se descompone en widgets que consumen este VM.
class PresenceViewModel {
  final PresenceRepository _repository;
  StreamSubscription<PresenceState>? _sub;
  PresenceState? _current;

  PresenceViewModel({required PresenceRepository repository})
      : _repository = repository;

  /// Carga el estado actual y suscribe al stream del repositorio.
  /// Debe llamarse post-login (Sem 5).
  Future<void> init() async {
    final result = await _repository.currentState();
    _current = result.valueOrNull;
    _sub = _repository.stateStream.listen((state) {
      _current = state;
    });
  }

  /// Stream de cambios: emite cada vez que el repositorio persiste un estado.
  Stream<PresenceState> get stateStream => _repository.stateStream;

  /// Última snapshot en memoria. Null antes de llamar a [init].
  PresenceState? get currentSnapshot => _current;

  void dispose() => _sub?.cancel();
}
