// lib/features/circle/data/datasources/circle_remote_data_source_impl.dart

// C:/projects/zync_app/lib/features/circle/data/datasources/circle_remote_data_source_impl.dart
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
      log("[CircleDataSource] 🔄 Stream evento recibido para users/$userId");
      
      if (!userSnap.exists) {
        log("[CircleDataSource] users/$userId no existe; emitiendo null.");
        return Stream.value(null);
      }

      final data = userSnap.data() ?? {};
      log("[CircleDataSource] Datos del usuario: $data");
      final String? circleId = data['circleId'] as String?;

      if (circleId == null || circleId.isEmpty) {
        log("[CircleDataSource] users/$userId.circleId es nulo o vacío; emitiendo null.");
        return Stream.value(null);
      }
      
      log("[CircleDataSource] ✅ Detectado circleId=$circleId; suscribiendo a circles/$circleId...");
      return _firestore
          .collection('circles')
          .doc(circleId)
          .snapshots()
          .transform(StreamTransformer.fromHandlers(
            handleData: (DocumentSnapshot circleDoc, EventSink<CircleModel?> sink) async {
              log("[CircleDataSource] 📄 Snapshot recibido para circles/${circleDoc.id}, exists: ${circleDoc.exists}");
              if (!circleDoc.exists) {
                log("[CircleDataSource] circles/$circleId ya no existe; emitiendo null.");
                sink.add(null);
              } else {
                log("[CircleDataSource] Pasando a CircleModel para hidratación...");
                final circleModel = await CircleModel.fromSnapshot(circleDoc);
                log("[CircleDataSource] ✅ CircleModel creado: ${circleModel.name}, miembros: ${circleModel.members.length}");
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

  @override
  Future<void> createCircle(String name, String creatorId) async {
    if (name.isEmpty) {
      throw ServerException(message: 'Circle name cannot be empty');
    }

    log("[CircleDataSource] Creando círculo '$name' para usuario $creatorId");
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

    log("[CircleDataSource] 🎯 REGISTRO - Estableciendo status inicial 'fine' para usuario $creatorId");
    log("[CircleDataSource] Iniciando transacción batch para crear círculo ${newCircleRef.id}");
    final batch = _firestore.batch();
    batch.set(newCircleRef, newCircleData);
    batch.update(userRef, {'circleId': newCircleRef.id});
    await batch.commit();
    log("[CircleDataSource] ✅ Círculo creado exitosamente. El stream debería detectar el cambio en users/$creatorId");
  }

  @override
  Future<DocumentSnapshot> getCircleDocument(String circleId) async {
    return _firestore.collection('circles').doc(circleId).get();
  }

  @override
  Future<void> joinCircle(String invitationCode, String userId) async {
    print('[CircleDataSource] joinCircle - código: $invitationCode, userId: $userId');
    
    if (invitationCode.isEmpty) {
      print('[CircleDataSource] Error: Código de invitación vacío');
      throw ServerException(message: 'Invitation code cannot be empty');
    }
    if (userId.isEmpty) {
      print('[CircleDataSource] Error: User ID vacío');
      throw ServerException(message: 'User ID cannot be empty');
    }

    print('[CircleDataSource] Buscando círculo con código de invitación...');
    final query = await _firestore
        .collection('circles')
        .where('invitation_code', isEqualTo: invitationCode)
        .limit(1)
        .get();
    
    print('[CircleDataSource] Círculos encontrados: ${query.docs.length}');
    if (query.docs.isEmpty) {
      print('[CircleDataSource] Error: Código de invitación inválido');
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

      log("[CircleDataSource] 🎯 UNIRSE - Estableciendo status inicial 'fine' para usuario $userId");

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
    // --- PUNTO DE TRAZA 5 ---
    log('[TRAZA 5/5] DataSource: Método "sendUserStatus" invocado. Preparando para escribir en Firestore...');
    
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
    log('[TRAZA-ÉXITO] DataSource: Escritura en Firestore completada.');
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
