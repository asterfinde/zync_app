import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_repository.dart';
import 'package:nunakin_app/contexts/geofencing/domain/zone_constraints.dart';
import 'package:nunakin_app/core/services/emoji_cache_service.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Edita una zona existente preservando `id`, `createdBy` y `createdAt`.
///
/// Carga la zona original desde el repositorio y aplica los cambios sobre ella,
/// de modo que los campos de auditoría no se pierden. Valida autenticación,
/// radio, pertenencia y nombre único (excluyendo la propia zona).
class UpdateZone {
  final ZoneRepository _repo;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  UpdateZone(this._repo, this._auth, this._firestore);

  Future<Result<Unit>> call({
    required String circleId,
    required String zoneId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required ZoneType type,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const FailureResult(AuthFailure(message: 'Usuario no autenticado'));
    }

    if (radiusMeters < ZoneConstraints.minRadiusMeters ||
        radiusMeters > ZoneConstraints.maxRadiusMeters) {
      return const FailureResult(ValidationFailure(
          message:
              'El radio debe estar entre ${ZoneConstraints.minRadiusMeters} y ${ZoneConstraints.maxRadiusMeters} metros'));
    }

    final membership = await _isMember(user.uid, circleId);
    if (membership.isFailure) {
      return FailureResult(membership.failureOrNull!);
    }
    if (membership.valueOrNull != true) {
      return const FailureResult(
          DomainFailure(message: 'No tienes permisos para editar zonas en este círculo'));
    }

    final originalResult = await _repo.getZone(circleId, zoneId);
    if (originalResult.isFailure) {
      return FailureResult(originalResult.failureOrNull!);
    }
    final original = originalResult.valueOrNull;
    if (original == null) {
      return const FailureResult(DomainFailure(message: 'Zona no encontrada'));
    }

    final existingResult = await _repo.getCircleZones(circleId);
    if (existingResult.isFailure) {
      return FailureResult(existingResult.failureOrNull!);
    }
    final duplicate = existingResult.valueOrNull!.any(
        (z) => z.id != zoneId && z.name.toLowerCase() == name.toLowerCase());
    if (duplicate) {
      return FailureResult(DomainFailure(message: 'Ya existe una zona con el nombre "$name"'));
    }

    final updated = original.copyWith(
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      type: type,
      isPredefined: type.isPredefinedType,
    );

    final result = await _repo.updateZone(updated);
    if (result.isSuccess) {
      unawaited(EmojiCacheService.syncEmojisToNativeCache());
    }
    return result;
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
