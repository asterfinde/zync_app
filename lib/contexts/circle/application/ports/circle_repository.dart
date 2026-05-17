import 'package:nunakin_app/contexts/circle/domain/circle_entity.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

abstract class CircleRepository {
  /// Stream tri-estado de membresía. Emite en cada cambio de Firestore.
  Stream<MembershipState> get membership;

  /// Obtiene los datos completos del círculo por ID.
  Future<CircleEntity?> getCircle(String circleId);

  /// Crea un nuevo círculo y retorna su ID.
  Future<String> createCircle(String name);

  /// Envía solicitud de ingreso al círculo con el código dado.
  /// El usuario queda en estado pendiente hasta que el creador apruebe.
  Future<Result<Unit>> requestToJoin(String invitationCode);

  /// Aprueba la solicitud de [requestingUserId] en [circleId].
  /// El servicio verifica que el caller sea el creador — lanza si no lo es.
  Future<Result<Unit>> approveJoin({
    required String circleId,
    required String requestingUserId,
  });

  /// Elimina la cuenta del usuario autenticado.
  /// Si es creador: borra el círculo. Si es miembro: sale del círculo.
  Future<Result<Unit>> deleteAccount();
}
