import 'package:nunakin_app/contexts/identity/domain/session_state.dart';

abstract class IdentityRepository {
  /// Stream continuo de cambios de sesión. Emite en cada login/logout.
  Stream<SessionState> get session;

  /// Última snapshot en memoria. `Anonymous` si nunca hubo login.
  SessionState get current;

  /// Cierra la sesión del usuario autenticado.
  Future<void> signOut();
}
