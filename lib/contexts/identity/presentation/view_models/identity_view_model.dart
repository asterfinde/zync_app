import 'dart:async';
import 'package:nunakin_app/contexts/identity/application/ports/identity_repository.dart';
import 'package:nunakin_app/contexts/identity/domain/session_state.dart';

class IdentityViewModel {
  final IdentityRepository _repository;
  StreamSubscription<SessionState>? _sub;
  SessionState? _current;

  IdentityViewModel({required IdentityRepository repository})
      : _repository = repository;

  /// Carga el estado actual y suscribe al stream. Llamar post-login (Sem 5).
  Future<void> init() async {
    _current = _repository.current;
    _sub = _repository.session.listen((state) {
      _current = state;
    });
  }

  /// Stream de cambios: emite cada vez que la sesión cambia.
  Stream<SessionState> get sessionStream => _repository.session;

  /// Última snapshot en memoria. Null antes de llamar a [init].
  SessionState? get currentSnapshot => _current;

  void dispose() => _sub?.cancel();
}
