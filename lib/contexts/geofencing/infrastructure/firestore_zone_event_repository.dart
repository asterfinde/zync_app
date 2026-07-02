import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_event_repository.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone_event.dart';

/// Implementación Firestore de [ZoneEventRepository].
///
/// Extracción 1:1 de la lógica viva de `ZoneEventService` (legacy): mismas
/// firmas throw-based y misma estructura de documento en
/// `/circles/{circleId}/zone_events`.
class FirestoreZoneEventRepository implements ZoneEventRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreZoneEventRepository(this._firestore, this._auth);

  CollectionReference<Map<String, dynamic>> _events(String circleId) =>
      _firestore.collection('circles').doc(circleId).collection('zone_events');

  @override
  Future<ZoneEvent> createEvent({
    required String circleId,
    required String zoneId,
    required ZoneEventType eventType,
    required double latitude,
    required double longitude,
    String? zoneName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final now = DateTime.now();
      final eventData = {
        'zoneId': zoneId,
        'userId': user.uid,
        'eventType': eventType.value,
        'timestamp': Timestamp.fromDate(now),
        'latitude': latitude,
        'longitude': longitude,
        if (zoneName != null) 'zoneName': zoneName,
      };

      final docRef = await _events(circleId).add(eventData);

      log('[ZoneEventRepository] ✅ Evento ${eventType.label} creado: ${docRef.id} para zona $zoneId');

      return ZoneEvent(
        id: docRef.id,
        zoneId: zoneId,
        userId: user.uid,
        eventType: eventType,
        timestamp: now,
        latitude: latitude,
        longitude: longitude,
        zoneName: zoneName,
      );
    } catch (e) {
      log('[ZoneEventRepository] ❌ Error creando evento: $e');
      rethrow;
    }
  }

  @override
  Stream<List<ZoneEvent>> listenToCircleEvents(String circleId) {
    return _events(circleId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ZoneEvent.fromFirestore(doc)).toList());
  }
}
