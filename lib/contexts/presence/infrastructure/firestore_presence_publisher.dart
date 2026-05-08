import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Adaptador de salida: publica cambios de presencia en Firestore.
///
/// Extrae la lógica de batch write de StatusService para que la
/// ruta de producción (Sem 5+) use use cases en vez del servicio estático.
///
/// En Sem 2, esta clase no se invoca desde código de producción.
class FirestorePresencePublisher implements PresencePublisher {
  final FirebaseFirestore _firestore;

  FirestorePresencePublisher(this._firestore);

  @override
  Future<Result<Unit>> publish({
    required PresenceState state,
    required String userId,
    required String circleId,
  }) async {
    try {
      final statusId = state.visibleStatusId;
      final batch    = _firestore.batch();

      final statusData = <String, dynamic>{
        'userId':          userId,
        'statusType':      statusId,
        'timestamp':       FieldValue.serverTimestamp(),
        'autoUpdated':     false,
        'manualOverride':  false,
        'locationUnknown': false,
      };

      if (state is SOSActive) {
        statusData['coordinates'] = {
          'latitude':  state.latitude,
          'longitude': state.longitude,
        };
      }

      batch.update(
        _firestore.collection('circles').doc(circleId),
        {'memberStatus.$userId': statusData},
      );

      final historyRef = _firestore
          .collection('circles').doc(circleId)
          .collection('statusEvents').doc();
      batch.set(historyRef, {
        'uid':        userId,
        'statusType': statusId,
        'createdAt':  FieldValue.serverTimestamp(),
        if (state is SOSActive) 'coordinates': {
          'latitude':  state.latitude,
          'longitude': state.longitude,
        },
      });

      await batch.commit().timeout(const Duration(seconds: 10));
      log('[FirestorePresencePublisher] ✅ Publicado: $statusId');
      return Success(Unit.instance);
    } catch (e, st) {
      log('[FirestorePresencePublisher] ❌ Error: $e');
      return FailureResult(NetworkFailure(
        message:    'Error publicando presencia: $e',
        cause:      e,
        stackTrace: st,
      ));
    }
  }
}
