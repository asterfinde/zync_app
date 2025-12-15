// lib/features/geofencing/services/zone_event_service.dart

import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/entities/zone_event.dart';

/// Servicio para gestionar eventos de entrada/salida de zonas
class ZoneEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crear un nuevo evento de zona
  /// Estructura: /circles/{circleId}/zone_events/{eventId}
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

      final docRef = await _firestore.collection('circles').doc(circleId).collection('zone_events').add(eventData);

      log('[ZoneEventService] ✅ Evento ${eventType.label} creado: ${docRef.id} para zona $zoneId');

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
      log('[ZoneEventService] ❌ Error creando evento: $e');
      rethrow;
    }
  }

  /// Obtener eventos de una zona específica
  Future<List<ZoneEvent>> getZoneEvents(String circleId, String zoneId) async {
    try {
      final snapshot = await _firestore
          .collection('circles')
          .doc(circleId)
          .collection('zone_events')
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => ZoneEvent.fromFirestore(doc)).toList();
    } catch (e) {
      log('[ZoneEventService] ❌ Error obteniendo eventos de zona: $e');
      return [];
    }
  }

  /// Obtener eventos de un usuario específico
  Future<List<ZoneEvent>> getUserEvents(String circleId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('circles')
          .doc(circleId)
          .collection('zone_events')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => ZoneEvent.fromFirestore(doc)).toList();
    } catch (e) {
      log('[ZoneEventService] ❌ Error obteniendo eventos de usuario: $e');
      return [];
    }
  }

  /// Escuchar eventos en tiempo real de un círculo
  Stream<List<ZoneEvent>> listenToCircleEvents(String circleId) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .collection('zone_events')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ZoneEvent.fromFirestore(doc)).toList();
    });
  }

  /// Obtener último evento de un usuario en una zona específica
  Future<ZoneEvent?> getLastEventForZone({
    required String circleId,
    required String userId,
    required String zoneId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('circles')
          .doc(circleId)
          .collection('zone_events')
          .where('userId', isEqualTo: userId)
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return ZoneEvent.fromFirestore(snapshot.docs.first);
    } catch (e) {
      log('[ZoneEventService] ❌ Error obteniendo último evento: $e');
      return null;
    }
  }

  /// Eliminar eventos antiguos (opcional, para limpieza)
  Future<void> deleteOldEvents(String circleId, {int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final snapshot = await _firestore
          .collection('circles')
          .doc(circleId)
          .collection('zone_events')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      log('[ZoneEventService] 🗑️ Eliminados ${snapshot.docs.length} eventos antiguos');
    } catch (e) {
      log('[ZoneEventService] ❌ Error eliminando eventos antiguos: $e');
    }
  }
}
