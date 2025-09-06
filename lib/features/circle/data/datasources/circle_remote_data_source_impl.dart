// lib/features/circle/data/datasources/circle_remote_data_source_impl.dart

import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/core/error/exceptions.dart';
import 'package:zync_app/features/circle/data/models/circle_model.dart';
import 'package:zync_app/features/circle/domain/entities/user_status.dart';
import 'circle_remote_data_source.dart';

class CircleRemoteDataSourceImpl implements CircleRemoteDataSource {
  final FirebaseFirestore _firestore;

  CircleRemoteDataSourceImpl(this._firestore);

  @override
  Stream<CircleModel?> getCircleStreamForUser(String userId) {
    log("[CircleDataSource] Creando stream para users/$userId -> circles/{circleId}...");

    final userDocStream =
        _firestore.collection('users').doc(userId).snapshots();

    return userDocStream.asyncExpand<CircleModel?>((userSnap) {
      if (!userSnap.exists) {
        log("[CircleDataSource] users/$userId no existe; emitiendo null.");
        return Stream.value(null);
      }

      final data = userSnap.data() ?? {};
      final String? circleId = data['circleId'] as String?;

      if (circleId == null || circleId.isEmpty) {
        log("[CircleDataSource] users/$userId.circleId es nulo o vacío; emitiendo null.");
        return Stream.value(null);
      }
      
      log("[CircleDataSource] Detectado circleId=$circleId; suscribiendo a circles/$circleId...");
      return _firestore
          .collection('circles')
          .doc(circleId)
          .snapshots()
          .transform(StreamTransformer.fromHandlers(
            handleData: (DocumentSnapshot circleDoc, EventSink<CircleModel?> sink) async {
              if (!circleDoc.exists) {
                log("[CircleDataSource] circles/$circleId ya no existe; emitiendo null.");
                sink.add(null);
              } else {
                log("[CircleDataSource] Recibido snapshot para circles/${circleDoc.id}. Pasando a CircleModel para hidratación ASÍNCRONA.");
                final circleModel = await CircleModel.fromSnapshot(circleDoc);
                sink.add(circleModel);
              }
            },
            handleError: (error, stackTrace, sink) {
              log("[CircleDataSource] Error en el stream del círculo: $error");
              sink.addError(error, stackTrace);
            },
          ));
    });
  }

  // CORRECCIÓN: Se reincorporan todos los métodos requeridos por la interfaz.
  @override
  Future<void> createCircle(String name, String creatorId) async {
    if (name.isEmpty) {
      throw ServerException(message: 'Circle name cannot be empty');
    }

    final newCircleRef = _firestore.collection('circles').doc();
    final userRef = _firestore.collection('users').doc(creatorId);
    final invitationCode = newCircleRef.id.substring(0, 6).toUpperCase();

    final initialStatus = {
      'userId': creatorId,
      'statusType': 'fine',
      'timestamp': FieldValue.serverTimestamp(),
    };

    final newCircleData = {
      'name': name,
      'invitation_code': invitationCode,
      'members': [creatorId],
      'memberStatus': {creatorId: initialStatus},
    };

    final batch = _firestore.batch();
    batch.set(newCircleRef, newCircleData);
    batch.update(userRef, {'circleId': newCircleRef.id});
    await batch.commit();
  }

  @override
  Future<DocumentSnapshot> getCircleDocument(String circleId) async {
    return _firestore.collection('circles').doc(circleId).get();
  }

  @override
  Future<void> joinCircle(String invitationCode, String userId) async {
    if (invitationCode.isEmpty) {
      throw ServerException(message: 'Invitation code cannot be empty');
    }
    if (userId.isEmpty) {
      throw ServerException(message: 'User ID cannot be empty');
    }

    final query = await _firestore
        .collection('circles')
        .where('invitation_code', isEqualTo: invitationCode)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw ServerException(message: 'Invalid invitation code.');
    }

    final circleRef = query.docs.first.reference;
    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final circleSnapshot = await transaction.get(circleRef);
      if (!circleSnapshot.exists) {
        throw ServerException(message: 'Circle does not exist.');
      }

      final List<String> currentMembers =
          List<String>.from(circleSnapshot.get('members') ?? []);

      if (currentMembers.contains(userId)) {
        throw ServerException(message: 'You are already a member of this circle.');
      }

      currentMembers.add(userId);

      final initialStatus = {
        'userId': userId,
        'statusType': 'fine',
        'timestamp': FieldValue.serverTimestamp(),
      };

      transaction.update(circleRef, {
        'members': currentMembers,
        'memberStatus.$userId': initialStatus,
      });

      transaction.update(userRef, {'circleId': circleRef.id});
    });
  }

  @override
  Future<void> sendUserStatus({
    required String circleId,
    required String userId,
    required StatusType statusType,
    Coordinates? coordinates,
  }) async {
    final circleRef = _firestore.collection('circles').doc(circleId);

    final Map<String, Object?> newStatusData = {
      'userId': userId,
      'statusType': statusType.name,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (coordinates != null) {
      newStatusData['coordinates'] =
          GeoPoint(coordinates.latitude, coordinates.longitude);
    }

    final batch = _firestore.batch();
    batch.update(circleRef, {'memberStatus.$userId': newStatusData});

    final historyRef = circleRef.collection('statusEvents').doc();
    batch.set(historyRef, {
      'uid': userId,
      'statusType': statusType.name,
      if (coordinates != null)
        'coordinates': GeoPoint(coordinates.latitude, coordinates.longitude),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  @override
  Future<CircleModel> getCircleByCreatorId(String creatorId) async {
    final query = await _firestore
        .collection('circles')
        .where('members', arrayContains: creatorId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw ServerException(message: 'No se encontró un círculo para el creador.');
    }
    return await CircleModel.fromSnapshot(query.docs.first);
  }
}