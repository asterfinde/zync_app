import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Puerto de acceso al estado de presencia persistido.
///
/// La impl lee/escribe las 5 claves de SharedPreferences que
/// hoy gestiona StatusService y SilentFunctionalityCoordinator
/// de forma incoherente entre sí.
abstract class PresenceRepository {
  /// Reconstruye el estado actual desde SharedPreferences.
  /// Si no hay datos, devuelve [Normal] con [StatusIds.fine].
  Future<Result<PresenceState>> currentState();

  /// Persiste coherentemente todas las claves necesarias para [state].
  Future<Result<Unit>> saveState(PresenceState state);

  /// Emite cada vez que se llama a [saveState] con éxito.
  /// Solo activo mientras el proceso Flutter esté en foreground.
  Stream<PresenceState> get stateStream;
}
