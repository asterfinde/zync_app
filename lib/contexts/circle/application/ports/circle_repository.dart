import 'package:nunakin_app/contexts/circle/domain/circle_entity.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';

abstract class CircleRepository {
  /// Stream tri-estado de membresía. Emite en cada cambio de Firestore.
  Stream<MembershipState> get membership;

  /// Obtiene los datos completos del círculo por ID.
  Future<CircleEntity?> getCircle(String circleId);

  /// Crea un nuevo círculo y retorna su ID.
  Future<String> createCircle(String name);
}
