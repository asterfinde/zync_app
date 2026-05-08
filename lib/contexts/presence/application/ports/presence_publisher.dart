import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Puerto de publicación: propaga cambios de presencia a sistemas externos.
/// La impl concreta (FirestorePresencePublisher) vive en infrastructure/ — Día 4.
abstract class PresencePublisher {
  /// Publica un cambio de estado al círculo vía Firestore.
  Future<Result<Unit>> publish({
    required PresenceState state,
    required String userId,
    required String circleId,
  });
}
