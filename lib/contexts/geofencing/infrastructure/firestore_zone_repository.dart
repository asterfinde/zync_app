import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_repository.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Implementación Firestore de [ZoneRepository].
///
/// Persistencia pura: sin validaciones de negocio ni side-effects
/// cross-context. Errores de Firestore se mapean a [UnexpectedFailure].
class FirestoreZoneRepository implements ZoneRepository {
  final FirebaseFirestore _firestore;

  FirestoreZoneRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _zones(String circleId) =>
      _firestore.collection('circles').doc(circleId).collection('zones');

  @override
  Future<Result<List<Zone>>> getCircleZones(String circleId) async {
    try {
      final snapshot =
          await _zones(circleId).orderBy('createdAt', descending: false).get();
      final zones = snapshot.docs.map((doc) => Zone.fromFirestore(doc)).toList();
      return Success(zones);
    } catch (e, st) {
      log('[ZoneRepository] ❌ getCircleZones: $e');
      return FailureResult(
          UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Zone?>> getZone(String circleId, String zoneId) async {
    try {
      final doc = await _zones(circleId).doc(zoneId).get();
      if (!doc.exists) return const Success(null);
      return Success(Zone.fromFirestore(doc));
    } catch (e, st) {
      log('[ZoneRepository] ❌ getZone: $e');
      return FailureResult(
          UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st));
    }
  }

  @override
  Stream<List<Zone>> watchCircleZones(String circleId) {
    return _zones(circleId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Zone.fromFirestore(doc)).toList());
  }

  @override
  Future<Result<Zone>> createZone(Zone zone) async {
    try {
      final ref =
          zone.id.isEmpty ? _zones(zone.circleId).doc() : _zones(zone.circleId).doc(zone.id);
      final persisted = zone.id.isEmpty ? zone.copyWith(id: ref.id) : zone;
      await ref.set(persisted.toFirestore());
      return Success(persisted);
    } catch (e, st) {
      log('[ZoneRepository] ❌ createZone: $e');
      return FailureResult(
          UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Unit>> updateZone(Zone zone) async {
    try {
      await _zones(zone.circleId).doc(zone.id).update(zone.toFirestore());
      return Success(Unit.instance);
    } catch (e, st) {
      log('[ZoneRepository] ❌ updateZone: $e');
      return FailureResult(
          UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Unit>> deleteZone(String circleId, String zoneId) async {
    try {
      await _zones(circleId).doc(zoneId).delete();
      return Success(Unit.instance);
    } catch (e, st) {
      log('[ZoneRepository] ❌ deleteZone: $e');
      return FailureResult(
          UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st));
    }
  }
}
