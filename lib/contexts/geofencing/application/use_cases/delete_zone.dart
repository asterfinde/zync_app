import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_repository.dart';
import 'package:nunakin_app/core/services/emoji_cache_service.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Elimina una zona y aplica los efectos asociados (REGLAS_NEGOCIO.md §9).
///
/// Tras borrar: resetea el `memberStatus` de los miembros que estaban en esa
/// zona (equivalente a una salida → `fine`) y sincroniza el cache nativo.
/// Ambos efectos son best-effort: no revierten el borrado si fallan.
class DeleteZone {
  final ZoneRepository _repo;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DeleteZone(this._repo, this._auth, this._firestore);

  Future<Result<Unit>> call({
    required String circleId,
    required String zoneId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const FailureResult(AuthFailure(message: 'Usuario no autenticado'));
    }

    final membership = await _isMember(user.uid, circleId);
    if (membership.isFailure) {
      return FailureResult(membership.failureOrNull!);
    }
    if (membership.valueOrNull != true) {
      return const FailureResult(
          DomainFailure(message: 'No tienes permisos para eliminar zonas en este círculo'));
    }

    final result = await _repo.deleteZone(circleId, zoneId);
    if (result.isFailure) return result;

    await _resetMemberStatusForDeletedZone(circleId, zoneId);
    unawaited(EmojiCacheService.syncEmojisToNativeCache());
    return result;
  }

  /// Resetea el `memberStatus` de todos los miembros cuyo estado activo
  /// apuntaba a la zona eliminada. REGLAS_NEGOCIO.md §9: salida de zona → `fine`.
  Future<void> _resetMemberStatusForDeletedZone(String circleId, String zoneId) async {
    try {
      final circleDoc = await _firestore.collection('circles').doc(circleId).get();
      final data = circleDoc.data();
      if (data == null) return;

      final memberStatus = data['memberStatus'] as Map<String, dynamic>?;
      if (memberStatus == null || memberStatus.isEmpty) return;

      final circleRef = _firestore.collection('circles').doc(circleId);
      final batch = _firestore.batch();
      var hasUpdates = false;

      for (final entry in memberStatus.entries) {
        final status = entry.value as Map<String, dynamic>?;
        if (status == null) continue;
        if ((status['zoneId'] as String?) != zoneId) continue;

        batch.update(circleRef, {
          'memberStatus.${entry.key}.statusType': 'fine',
          'memberStatus.${entry.key}.customEmoji': FieldValue.delete(),
          'memberStatus.${entry.key}.zoneName': FieldValue.delete(),
          'memberStatus.${entry.key}.zoneId': FieldValue.delete(),
          'memberStatus.${entry.key}.autoUpdated': true,
          'memberStatus.${entry.key}.timestamp': FieldValue.serverTimestamp(),
        });
        hasUpdates = true;
        log('[DeleteZone] 🔄 Reset status miembro ${entry.key} (zona eliminada $zoneId)');
      }

      if (hasUpdates) await batch.commit();
    } catch (e) {
      log('[DeleteZone] ❌ Error reseteando memberStatus post-delete: $e');
    }
  }

  Future<Result<bool>> _isMember(String userId, String circleId) async {
    try {
      final doc = await _firestore.collection('circles').doc(circleId).get();
      if (!doc.exists) {
        return const FailureResult(DomainFailure(message: 'Círculo no encontrado'));
      }
      final members = List<String>.from(doc.data()?['members'] as List? ?? const []);
      return Success(members.contains(userId));
    } catch (e, st) {
      return FailureResult(UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st));
    }
  }
}
