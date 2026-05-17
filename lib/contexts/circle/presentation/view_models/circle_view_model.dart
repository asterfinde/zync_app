import 'dart:async';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';

class CircleViewModel {
  final CircleRepository _repository;
  StreamSubscription<MembershipState>? _sub;
  MembershipState? _current;

  CircleViewModel({required CircleRepository repository})
      : _repository = repository;

  /// Suscribe al stream de membresía. Llamar post-login (Sem 5).
  Future<void> init() async {
    _sub = _repository.membership.listen((state) {
      _current = state;
    });
  }

  /// Stream de cambios de membresía.
  Stream<MembershipState> get membershipStream => _repository.membership;

  /// Última snapshot. Null antes de [init] o hasta el primer evento del stream.
  MembershipState? get currentSnapshot => _current;

  void dispose() => _sub?.cancel();
}
