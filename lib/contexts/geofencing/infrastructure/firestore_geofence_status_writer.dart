import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/geofence_status_writer.dart';
import 'package:nunakin_app/shared/events/domain_event.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class FirestoreGeofenceStatusWriter implements GeofenceStatusWriter {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreGeofenceStatusWriter(this._firestore, this._auth);

  @override
  Future<Result<Unit>> onZoneEntered(ZoneEntered event) async {
    if (event.circleId.isEmpty) return Success(Unit.instance);

    final user = _auth.currentUser;
    if (user == null) return Success(Unit.instance);

    try {
      if (await _hasManualOverride(event.circleId, user.uid)) {
        log('[GeofenceStatusWriter] ⏸️ Omitido — manualOverride activo (zona: ${event.zoneName})');
        return Success(Unit.instance);
      }

      final String statusType = _statusFromZoneType(event.zoneTypeValue);
      final String customEmoji = event.isPredefined ? _emojiFromZoneType(event.zoneTypeValue) : '📍';

      await _firestore.collection('circles').doc(event.circleId).update({
        'memberStatus.${user.uid}': {
          'statusType':  statusType,
          'customEmoji': customEmoji,
          'zoneName':    event.zoneName,
          'zoneId':      event.zoneId,
          'autoUpdated': true,
          'timestamp':   FieldValue.serverTimestamp(),
        },
      });

      log('[GeofenceStatusWriter] ✅ Entrada zona: $statusType (${event.zoneName})');
      return Success(Unit.instance);
    } catch (e, st) {
      log('[GeofenceStatusWriter] ❌ Error en entrada: $e');
      return FailureResult(UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<Unit>> onZoneExited(ZoneExited event) async {
    if (event.circleId.isEmpty) return Success(Unit.instance);

    final user = _auth.currentUser;
    if (user == null) return Success(Unit.instance);

    try {
      await _firestore.collection('circles').doc(event.circleId).update({
        'memberStatus.${user.uid}': {
          'statusType':       'fine',
          'customEmoji':      null,
          'zoneName':         null,
          'zoneId':           null,
          'autoUpdated':      true,
          'lastKnownZone':    event.zoneId,
          'lastKnownZoneTime': FieldValue.serverTimestamp(),
          'timestamp':        FieldValue.serverTimestamp(),
        },
      });

      log('[GeofenceStatusWriter] ✅ Salida de zona — estado: fine');
      return Success(Unit.instance);
    } catch (e, st) {
      log('[GeofenceStatusWriter] ❌ Error en salida: $e');
      return FailureResult(UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st));
    }
  }

  Future<bool> _hasManualOverride(String circleId, String userId) async {
    final doc = await _firestore.collection('circles').doc(circleId).get();
    final memberStatus = doc.data()?['memberStatus'] as Map<String, dynamic>?;
    final userStatus   = memberStatus?[userId] as Map<String, dynamic>?;
    return userStatus?['manualOverride'] as bool? ?? false;
  }

  String _statusFromZoneType(String zoneTypeValue) {
    switch (zoneTypeValue) {
      case 'school':
      case 'university':
        return 'studying';
      case 'work':
        return 'busy';
      default:
        return 'fine';
    }
  }

  String _emojiFromZoneType(String zoneTypeValue) {
    switch (zoneTypeValue) {
      case 'home':       return '🏠';
      case 'school':     return '🏫';
      case 'university': return '🎓';
      case 'work':       return '💼';
      default:           return '📍';
    }
  }
}
