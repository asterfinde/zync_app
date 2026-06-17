import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_repository.dart';
import 'package:nunakin_app/contexts/geofencing/domain/zone_constraints.dart';
import 'package:nunakin_app/core/services/emoji_cache_service.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';

/// Crea una zona aplicando las reglas de negocio (REGLAS_NEGOCIO.md §7).
///
/// Validaciones (en orden): autenticación, radio, pertenencia al círculo,
/// máximo de zonas, nombre único. La persistencia delega en [ZoneRepository];
/// el sync del cache nativo es best-effort (no bloquea el resultado).
class CreateZone {
  final ZoneRepository _repo;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CreateZone(this._repo, this._auth, this._firestore);

  Future<Result<Zone>> call({
    required String circleId,
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
          DomainFailure(message: 'No tienes permisos para crear zonas en este círculo'));
    }

    final existingResult = await _repo.getCircleZones(circleId);
    if (existingResult.isFailure) {
      return FailureResult(existingResult.failureOrNull!);
    }
    final existing = existingResult.valueOrNull!;

    if (existing.length >= ZoneConstraints.maxZonesPerCircle) {
      return const FailureResult(DomainFailure(
          message: 'Máximo ${ZoneConstraints.maxZonesPerCircle} zonas por círculo alcanzado'));
    }

    if (existing.any((z) => z.name.toLowerCase() == name.toLowerCase())) {
      return FailureResult(DomainFailure(message: 'Ya existe una zona con el nombre "$name"'));
    }

    final zone = Zone(
      id: '',
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      circleId: circleId,
      createdBy: user.uid,
      createdAt: DateTime.now(),
      type: type,
      isPredefined: type.isPredefinedType,
    );

    final result = await _repo.createZone(zone);
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
