// lib/services/circle_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Modelos ────────────────────────────────────────────────────────────────

class Circle {
  final String id;
  final String name;
  final String invitationCode;
  final List<String> members;
  final String creatorId;

  Circle({
    required this.id,
    required this.name,
    required this.invitationCode,
    required this.members,
    required this.creatorId,
  });

  factory Circle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Circle(
      id: doc.id,
      name: data['name'] ?? '',
      invitationCode: data['invitation_code'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      creatorId: data['creatorId'] ?? '',
    );
  }
}

class JoinRequest {
  final String userId;
  final String nickname;
  final String email;
  final DateTime? requestedAt;
  final String status; // "pending" | "approved" | "rejected"

  JoinRequest({
    required this.userId,
    required this.nickname,
    required this.email,
    this.requestedAt,
    required this.status,
  });

  factory JoinRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['requestedAt'] as Timestamp?;
    return JoinRequest(
      userId: doc.id,
      nickname: data['nickname'] ?? '',
      email: data['email'] ?? '',
      requestedAt: ts?.toDate(),
      status: data['status'] ?? 'pending',
    );
  }
}

// ─── Estado tri-estado del usuario respecto al círculo ──────────────────────

sealed class UserCircleState {}

final class UserInCircle extends UserCircleState {
  final Circle circle;
  UserInCircle(this.circle);
}

final class UserPendingRequest extends UserCircleState {
  final String pendingCircleId;
  UserPendingRequest(this.pendingCircleId);
}

final class UserNoCircle extends UserCircleState {}

// ─── Servicio ────────────────────────────────────────────────────────────────

class CircleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // StreamController para forzar actualizaciones
  static final StreamController<void> _refreshController =
      StreamController<void>.broadcast();

  /// Crea un nuevo círculo para el usuario actual
  Future<String> createCircle(String name) async {
    log('[CircleService] Creando círculo: $name');

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    // Validación MVP: un solo círculo por usuario
    final existingUserDoc =
        await _firestore.collection('users').doc(user.uid).get();
    if (existingUserDoc.exists) {
      final existingCircleId =
          existingUserDoc.data()?['circleId'] as String?;
      if (existingCircleId != null && existingCircleId.isNotEmpty) {
        throw Exception(
            'Ya perteneces a un círculo. En esta versión solo puedes pertenecer a uno.');
      }
      final pendingCircleId =
          existingUserDoc.data()?['pendingCircleId'] as String?;
      if (pendingCircleId != null && pendingCircleId.isNotEmpty) {
        throw Exception(
            'Tienes una solicitud de ingreso pendiente. Cancela la solicitud antes de crear un círculo.');
      }
    }

    final circleRef = _firestore.collection('circles').doc();
    final invitationCode = circleRef.id.substring(0, 6).toUpperCase();

    final initialStatus = {
      'userId': user.uid,
      'statusType': 'fine',
      'timestamp': FieldValue.serverTimestamp(),
    };

    final circleData = {
      'name': name,
      'invitation_code': invitationCode,
      'members': [user.uid],
      'memberStatus': {user.uid: initialStatus},
      'creatorId': user.uid,
    };

    // Usar batch para operación atómica
    final batch = _firestore.batch();
    batch.set(circleRef, circleData);
    batch.update(_firestore.collection('users').doc(user.uid), {
      'circleId': circleRef.id
    });

    await batch.commit();
    log('[CircleService] ✅ Círculo creado exitosamente: ${circleRef.id}');

    // Forzar actualización del stream
    _refreshController.add(null);

    return circleRef.id;
  }

  /// Une al usuario actual a un círculo existente usando código de invitación.
  /// Método legado — solo para uso interno o tests.
  Future<void> joinCircle(String invitationCode) async {
    log('[CircleService] Uniéndose al círculo con código: $invitationCode');

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    if (invitationCode.isEmpty) {
      throw Exception('Código de invitación vacío');
    }

    // Buscar círculo por código de invitación
    final query = await _firestore
        .collection('circles')
        .where('invitation_code', isEqualTo: invitationCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Código de invitación inválido');
    }

    final circleRef = query.docs.first.reference;

    await _firestore.runTransaction((transaction) async {
      final circleSnapshot = await transaction.get(circleRef);

      if (!circleSnapshot.exists) {
        throw Exception('El círculo no existe');
      }

      final currentMembers =
          List<String>.from(circleSnapshot.get('members') ?? []);

      if (currentMembers.contains(user.uid)) {
        throw Exception('Ya eres miembro de este círculo');
      }

      currentMembers.add(user.uid);

      final initialStatus = {
        'userId': user.uid,
        'statusType': 'fine',
        'timestamp': FieldValue.serverTimestamp(),
      };

      transaction.update(circleRef, {
        'members': currentMembers,
        'memberStatus.${user.uid}': initialStatus,
      });

      transaction.update(_firestore.collection('users').doc(user.uid), {
        'circleId': circleRef.id,
      });
    });

    // Forzar actualización del stream
    _refreshController.add(null);

    log('[CircleService] ✅ Usuario se unió al círculo exitosamente');
  }

  /// Envía una solicitud de ingreso al círculo con el código dado.
  /// El usuario queda en estado pendiente hasta que el creador apruebe o rechace.
  Future<void> requestToJoinCircle(String invitationCode) async {
    log('[CircleService] Enviando solicitud de ingreso con código: $invitationCode');

    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    if (invitationCode.isEmpty) throw Exception('Código de invitación vacío');

    // Buscar el círculo por código
    final query = await _firestore
        .collection('circles')
        .where('invitation_code', isEqualTo: invitationCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception('Código de invitación inválido');

    final circleDoc = query.docs.first;
    final circleId = circleDoc.id;

    // ¿Ya es miembro?
    final currentMembers =
        List<String>.from(circleDoc.data()['members'] ?? []);
    if (currentMembers.contains(user.uid)) {
      throw Exception('Ya eres miembro de este círculo');
    }

    // ¿Ya tiene una solicitud pendiente (en cualquier círculo)?
    final userDoc =
        await _firestore.collection('users').doc(user.uid).get();
    final existingPending =
        userDoc.data()?['pendingCircleId'] as String?;
    if (existingPending != null && existingPending.isNotEmpty) {
      throw Exception('Ya tienes una solicitud pendiente');
    }

    // ¿Fue rechazado anteriormente en este círculo?
    final existingRequest = await _firestore
        .collection('circles')
        .doc(circleId)
        .collection('joinRequests')
        .doc(user.uid)
        .get();

    if (existingRequest.exists) {
      final status = existingRequest.data()?['status'] as String?;
      if (status == 'rejected') {
        throw Exception(
            'Tu solicitud fue rechazada anteriormente por este círculo');
      }
    }

    // Obtener nickname y email del solicitante (desnormalización)
    final nickname = userDoc.data()?['nickname'] as String? ?? '';
    final email = user.email ?? '';

    // Batch: crear joinRequest + setear pendingCircleId
    final batch = _firestore.batch();
    batch.set(
      _firestore
          .collection('circles')
          .doc(circleId)
          .collection('joinRequests')
          .doc(user.uid),
      {
        'nickname': nickname,
        'email': email,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      },
    );
    batch.update(_firestore.collection('users').doc(user.uid), {
      'pendingCircleId': circleId,
    });

    await batch.commit();
    log('[CircleService] ✅ Solicitud enviada al círculo: $circleId');
    _refreshController.add(null);
  }

  /// Aprueba la solicitud de ingreso de [requestingUserId] al [circleId].
  /// Solo el creador del círculo puede llamar a este método.
  Future<void> approveJoinRequest(
      String circleId, String requestingUserId) async {
    log('[CircleService] Aprobando solicitud de $requestingUserId en $circleId');

    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final circleRef = _firestore.collection('circles').doc(circleId);
    final circleDoc = await circleRef.get();
    if (!circleDoc.exists) throw Exception('El círculo no existe');

    final creatorId = circleDoc.data()?['creatorId'] as String? ?? '';
    if (user.uid != creatorId) {
      throw Exception('Solo el creador puede aprobar solicitudes');
    }

    final initialStatus = {
      'userId': requestingUserId,
      'statusType': 'fine',
      'timestamp': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    // Marcar joinRequest como aprobado
    batch.update(
      circleRef.collection('joinRequests').doc(requestingUserId),
      {'status': 'approved'},
    );
    // Agregar al círculo
    batch.update(circleRef, {
      'members': FieldValue.arrayUnion([requestingUserId]),
      'memberStatus.$requestingUserId': initialStatus,
    });
    // Actualizar documento del usuario
    batch.update(_firestore.collection('users').doc(requestingUserId), {
      'circleId': circleId,
      'pendingCircleId': FieldValue.delete(),
    });

    await batch.commit();
    log('[CircleService] ✅ Solicitud aprobada para: $requestingUserId');
    _refreshController.add(null);
  }

  /// Rechaza la solicitud de ingreso de [requestingUserId] al [circleId].
  /// Solo el creador del círculo puede llamar a este método.
  Future<void> rejectJoinRequest(
      String circleId, String requestingUserId) async {
    log('[CircleService] Rechazando solicitud de $requestingUserId en $circleId');

    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final circleRef = _firestore.collection('circles').doc(circleId);
    final circleDoc = await circleRef.get();
    if (!circleDoc.exists) throw Exception('El círculo no existe');

    final creatorId = circleDoc.data()?['creatorId'] as String? ?? '';
    if (user.uid != creatorId) {
      throw Exception('Solo el creador puede rechazar solicitudes');
    }

    final batch = _firestore.batch();
    // Marcar joinRequest como rechazado (persistente: bloquea reintentos)
    batch.update(
      circleRef.collection('joinRequests').doc(requestingUserId),
      {'status': 'rejected'},
    );
    // Limpiar pendingCircleId del usuario
    batch.update(_firestore.collection('users').doc(requestingUserId), {
      'pendingCircleId': FieldValue.delete(),
    });

    await batch.commit();
    log('[CircleService] ✅ Solicitud rechazada para: $requestingUserId');
    _refreshController.add(null);
  }

  /// Stream de las solicitudes pendientes de ingreso a un círculo.
  /// Solo el creador debería suscribirse a este stream.
  Stream<List<JoinRequest>> getPendingJoinRequestsStream(String circleId) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .collection('joinRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(JoinRequest.fromFirestore).toList());
  }

  /// Obtiene el círculo actual del usuario
  Future<Circle?> getUserCircle() async {
    final user = _auth.currentUser;
    if (user == null) {
      log('[CircleService] Usuario no autenticado');
      return null;
    }

    try {
      final userSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      if (!userSnapshot.exists) {
        log('[CircleService] Documento de usuario no existe');
        return null;
      }

      final circleId = userSnapshot.data()?['circleId'] as String?;

      if (circleId == null || circleId.isEmpty) {
        log('[CircleService] Usuario no tiene círculo asignado');
        return null;
      }

      final circleDoc =
          await _firestore.collection('circles').doc(circleId).get();

      if (!circleDoc.exists) {
        log('[CircleService] Círculo no existe: $circleId');
        return null;
      }

      final circle = Circle.fromFirestore(circleDoc);
      log('[CircleService] ✅ Círculo obtenido: ${circle.name}');
      return circle;
    } catch (e) {
      log('[CircleService] Error obteniendo círculo: $e');
      return null;
    }
  }

  /// Stream tri-estado: UserInCircle | UserPendingRequest | UserNoCircle
  Stream<UserCircleState> getUserCircleStream() {
    final user = _auth.currentUser;
    if (user == null) {
      log('[CircleService] Usuario no autenticado para stream');
      return Stream.value(UserNoCircle());
    }

    late StreamController<UserCircleState> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
        userSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
        circleSubscription;
    StreamSubscription<void>? refreshSubscription;

    controller = StreamController<UserCircleState>(
      onListen: () {
        void processUserSnapshot(
            DocumentSnapshot<Map<String, dynamic>> userSnapshot) async {
          if (!userSnapshot.exists) {
            log('[CircleService] Stream: Usuario no existe');
            controller.add(UserNoCircle());
            return;
          }

          final data = userSnapshot.data()!;
          final circleId = data['circleId'] as String?;
          final pendingCircleId = data['pendingCircleId'] as String?;

          if (circleId != null && circleId.isNotEmpty) {
            // Usuario está en un círculo → escuchar cambios del círculo
            log('[CircleService] Stream: Escuchando círculo $circleId');
            await circleSubscription?.cancel();
            circleSubscription = _firestore
                .collection('circles')
                .doc(circleId)
                .snapshots()
                .listen((circleSnapshot) {
              if (!circleSnapshot.exists) {
                log('[CircleService] Stream: Círculo eliminado');
                controller.add(UserNoCircle());
                return;
              }
              final state = UserInCircle(Circle.fromFirestore(circleSnapshot));
              log('[CircleService] Stream: ✅ Círculo actualizado: ${state.circle.name}');
              controller.add(state);
            });
          } else if (pendingCircleId != null && pendingCircleId.isNotEmpty) {
            // Usuario tiene solicitud pendiente
            log('[CircleService] Stream: Solicitud pendiente en $pendingCircleId');
            await circleSubscription?.cancel();
            circleSubscription = null;
            controller.add(UserPendingRequest(pendingCircleId));
          } else {
            // Sin círculo
            log('[CircleService] Stream: Usuario sin círculo');
            await circleSubscription?.cancel();
            circleSubscription = null;
            controller.add(UserNoCircle());
          }
        }

        // Escuchar cambios en el documento del usuario
        userSubscription = _firestore
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen(
          processUserSnapshot,
          onError: (e) {
            log('[CircleService] Stream: Error en userSubscription (logout?): $e');
            if (!controller.isClosed) {
              controller.add(UserNoCircle());
            }
          },
        );

        // Escuchar señales de refresh manual
        refreshSubscription = _refreshController.stream.listen((_) async {
          final currentUser = _auth.currentUser;
          if (currentUser == null) return;
          log('[CircleService] Stream: Refresh manual activado');
          final userDoc =
              await _firestore.collection('users').doc(currentUser.uid).get();
          processUserSnapshot(userDoc);
        });
      },
      onCancel: () async {
        await userSubscription?.cancel();
        await circleSubscription?.cancel();
        await refreshSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid) async {
    return await FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  /// Permite al usuario actual salir del círculo
  Future<void> leaveCircle() async {
    log('[CircleService] Usuario saliendo del círculo');

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    try {
      // Obtener el círculo actual del usuario
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      if (!userDoc.exists ||
          userData == null ||
          !userData.containsKey('circleId')) {
        throw Exception('El usuario no está en ningún círculo');
      }

      final circleId = userData['circleId'] as String;

      // Usar transacción para asegurar consistencia
      await _firestore.runTransaction((transaction) async {
        final circleRef = _firestore.collection('circles').doc(circleId);
        final circleDoc = await transaction.get(circleRef);

        if (!circleDoc.exists) {
          throw Exception('El círculo no existe');
        }

        final members =
            List<String>.from(circleDoc.data()!['members'] ?? []);

        // Verificar que el usuario esté realmente en el círculo
        if (!members.contains(user.uid)) {
          throw Exception('El usuario no está en este círculo');
        }

        // Remover al usuario de la lista de miembros
        members.remove(user.uid);

        // Si es el último miembro, eliminar el círculo completamente
        if (members.isEmpty) {
          transaction.delete(circleRef);
          log('[CircleService] Círculo eliminado (último miembro salió)');
        } else {
          // Actualizar la lista de miembros del círculo
          transaction
              .update(circleRef, {'members': members});
          log('[CircleService] Usuario removido del círculo. Miembros restantes: ${members.length}');
        }

        // Remover circleId del documento del usuario
        transaction
            .update(_firestore.collection('users').doc(user.uid), {
          'circleId': FieldValue.delete(),
        });
      });

      // Forzar actualización del stream
      _refreshController.add(null);

      log('[CircleService] Usuario salió del círculo exitosamente');
    } catch (e) {
      log('[CircleService] Error al salir del círculo: $e');
      rethrow;
    }
  }

  /// Elimina la cuenta del usuario actual.
  /// Si es creador del círculo: elimina el círculo y desvincula a todos los miembros.
  /// Si es miembro común: solo lo remueve del círculo.
  /// Borra el documento de Firestore y luego la cuenta de Firebase Auth.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final uid = user.uid;

    // 1. Manejar círculo según rol (creador vs miembro común)
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId != null && circleId.isNotEmpty) {
        final circleDoc =
            await _firestore.collection('circles').doc(circleId).get();
        if (circleDoc.exists) {
          final creatorId =
              circleDoc.data()?['creatorId'] as String? ?? '';
          if (uid == creatorId) {
            // Es el creador: eliminar el círculo y desvincular a todos los miembros
            final members = List<String>.from(
                circleDoc.data()?['members'] ?? []);
            final batch = _firestore.batch();
            batch.delete(_firestore.collection('circles').doc(circleId));
            for (final memberId in members) {
              if (memberId != uid) {
                batch.update(
                    _firestore.collection('users').doc(memberId), {
                  'circleId': FieldValue.delete(),
                });
              }
            }
            await batch.commit();
            log('[CircleService] ✅ Círculo eliminado por su creador. Miembros desvinculados: ${members.length - 1}');
          } else {
            // Es miembro común: solo salir del círculo
            await leaveCircle();
          }
        }
      }

      // Limpiar pendingCircleId si existe
      final pendingCircleId =
          userDoc.data()?['pendingCircleId'] as String?;
      if (pendingCircleId != null && pendingCircleId.isNotEmpty) {
        await _firestore
            .collection('circles')
            .doc(pendingCircleId)
            .collection('joinRequests')
            .doc(uid)
            .update({'status': 'cancelled'});
      }
    }

    // 2. Borrar documento del usuario en Firestore PRIMERO
    // (request.auth sigue válido aquí; la sesión todavía existe)
    await _firestore.collection('users').doc(uid).delete();

    // 3. Borrar cuenta de Firebase Auth
    // Si la sesión no es reciente, lanza requires-recent-login.
    // El doc de Firestore ya fue eliminado, pero el usuario puede reintentar.
    await user.delete();
  }

  /// Método para forzar actualización manual del stream
  static void forceRefresh() {
    _refreshController.add(null);
  }

  /// Dispose del StreamController
  static void dispose() {
    _refreshController.close();
  }
}
