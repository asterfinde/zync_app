// lib/features/geofencing/services/zone_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/entities/zone.dart';

/// Servicio para gestión de zonas geográficas
/// CRUD completo + validaciones de límites
class ZoneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int MAX_ZONES_PER_CIRCLE = 10;
  static const double MIN_RADIUS_METERS = 50.0;
  static const double MAX_RADIUS_METERS = 500.0;

  /// Crear nueva zona
  /// Valida límites y permisos
  Future<Zone> createZone({
    required String circleId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required ZoneType type,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuario no autenticado');
    }

    // Validar radio
    if (radiusMeters < MIN_RADIUS_METERS || radiusMeters > MAX_RADIUS_METERS) {
      throw Exception('Radio debe estar entre $MIN_RADIUS_METERS y $MAX_RADIUS_METERS metros');
    }

    // Validar máximo de zonas
    final existingZones = await getCircleZones(circleId);
    if (existingZones.length >= MAX_ZONES_PER_CIRCLE) {
      throw Exception('Máximo $MAX_ZONES_PER_CIRCLE zonas por círculo alcanzado');
    }

    // Validar nombre único en el círculo
    final duplicateName = existingZones.any((z) => z.name.toLowerCase() == name.toLowerCase());
    if (duplicateName) {
      throw Exception('Ya existe una zona con el nombre "$name"');
    }

    // Validar permisos (usuario debe pertenecer al círculo)
    final isMember = await _verifyCircleMembership(currentUser.uid, circleId);
    if (!isMember) {
      throw Exception('No tienes permisos para crear zonas en este círculo');
    }

    // Crear zona
    final zoneRef = _firestore.collection('circles').doc(circleId).collection('zones').doc();

    final zone = Zone(
      id: zoneRef.id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      circleId: circleId,
      createdBy: currentUser.uid,
      createdAt: DateTime.now(),
      type: type,
    );

    await zoneRef.set(zone.toFirestore());

    print('✅ [ZoneService] Zona creada: ${zone.name} (${zone.radiusMeters}m)');

    return zone;
  }

  /// Actualizar zona existente
  Future<void> updateZone({
    required String circleId,
    required String zoneId,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    ZoneType? type,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuario no autenticado');
    }

    // Validar radio si se proporciona
    if (radiusMeters != null && (radiusMeters < MIN_RADIUS_METERS || radiusMeters > MAX_RADIUS_METERS)) {
      throw Exception('Radio debe estar entre $MIN_RADIUS_METERS y $MAX_RADIUS_METERS metros');
    }

    // Validar permisos
    final isMember = await _verifyCircleMembership(currentUser.uid, circleId);
    if (!isMember) {
      throw Exception('No tienes permisos para editar zonas en este círculo');
    }

    // Validar nombre único si se cambia
    if (name != null) {
      final existingZones = await getCircleZones(circleId);
      final duplicateName = existingZones.any((z) => z.id != zoneId && z.name.toLowerCase() == name.toLowerCase());
      if (duplicateName) {
        throw Exception('Ya existe una zona con el nombre "$name"');
      }
    }

    final zoneRef = _firestore.collection('circles').doc(circleId).collection('zones').doc(zoneId);

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;
    if (radiusMeters != null) updates['radiusMeters'] = radiusMeters;
    if (type != null) updates['type'] = type.value;

    if (updates.isEmpty) {
      throw Exception('No hay cambios para actualizar');
    }

    await zoneRef.update(updates);

    print('✅ [ZoneService] Zona actualizada: $zoneId');
  }

  /// Eliminar zona
  Future<void> deleteZone({
    required String circleId,
    required String zoneId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuario no autenticado');
    }

    // Validar permisos
    final isMember = await _verifyCircleMembership(currentUser.uid, circleId);
    if (!isMember) {
      throw Exception('No tienes permisos para eliminar zonas en este círculo');
    }

    await _firestore.collection('circles').doc(circleId).collection('zones').doc(zoneId).delete();

    print('✅ [ZoneService] Zona eliminada: $zoneId');
  }

  /// Obtener todas las zonas de un círculo
  Future<List<Zone>> getCircleZones(String circleId) async {
    final snapshot = await _firestore
        .collection('circles')
        .doc(circleId)
        .collection('zones')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map((doc) => Zone.fromFirestore(doc)).toList();
  }

  /// Stream de zonas para actualización en tiempo real
  Stream<List<Zone>> listenToZones(String circleId) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .collection('zones')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Zone.fromFirestore(doc)).toList());
  }

  /// Obtener zona por ID
  Future<Zone?> getZone(String circleId, String zoneId) async {
    final doc = await _firestore.collection('circles').doc(circleId).collection('zones').doc(zoneId).get();

    if (!doc.exists) return null;

    return Zone.fromFirestore(doc);
  }

  /// Verificar si usuario pertenece al círculo
  Future<bool> _verifyCircleMembership(String userId, String circleId) async {
    final circleDoc = await _firestore.collection('circles').doc(circleId).get();

    if (!circleDoc.exists) {
      throw Exception('Círculo no encontrado');
    }

    final data = circleDoc.data() as Map<String, dynamic>;
    final members = List<String>.from(data['members'] as List<dynamic>);

    return members.contains(userId);
  }

  /// Encontrar zona que contiene una ubicación
  Future<Zone?> findZoneContainingLocation({
    required String circleId,
    required double latitude,
    required double longitude,
  }) async {
    final zones = await getCircleZones(circleId);

    for (final zone in zones) {
      if (zone.containsLocation(latitude, longitude)) {
        return zone;
      }
    }

    return null;
  }

  /// Validar si se puede crear más zonas (para UI)
  Future<bool> canCreateMoreZones(String circleId) async {
    final zones = await getCircleZones(circleId);
    return zones.length < MAX_ZONES_PER_CIRCLE;
  }
}
