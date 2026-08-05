// lib/services/circle_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
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
  static final StreamController<void> _refreshController = StreamController<void>.broadcast();

  /// Crea un nuevo círculo para el usuario actual
  Future<String> createCircle(String name) async {
    log('[CircleService] Creando círculo: $name');

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    // Validación MVP: un solo círculo por usuario
    final existingUserDoc = await _firestore.collection('users').doc(user.uid).get();
    if (existingUserDoc.exists) {
      final existingCircleId = existingUserDoc.data()?['circleId'] as String?;
      if (existingCircleId != null && existingCircleId.isNotEmpty) {
        throw Exception('Ya perteneces a un círculo. En esta versión solo puedes pertenecer a uno.');
      }
      final pendingCircleId = existingUserDoc.data()?['pendingCircleId'] as String?;
      if (pendingCircleId != null && pendingCircleId.isNotEmpty) {
        throw Exception('Tienes una solicitud de ingreso pendiente. Cancela la solicitud antes de crear un círculo.');
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
    batch.set(
      _firestore.collection('users').doc(user.uid),
      {'circleId': circleRef.id},
      SetOptions(merge: true),
    );
    // Lookup mínimo por código (DT-RULES-CIRCLES-OPEN): un no-miembro no
    // puede leer/listar `circles` bajo las reglas nuevas, así que unirse
    // por código necesita esta colección aparte, sin datos sensibles.
    batch.set(
      _firestore.collection('circleInvites').doc(invitationCode),
      {'circleId': circleRef.id},
    );

    await batch.commit();
    log('[CircleService] ✅ Círculo creado exitosamente: ${circleRef.id}');

    // Forzar actualización del stream
    _refreshController.add(null);

    return circleRef.id;
  }

  /// Envía una solicitud de ingreso al círculo con el código dado.
  /// El usuario queda en estado pendiente hasta que el creador apruebe o rechace.
  Future<void> requestToJoinCircle(String invitationCode) async {
    log('[CircleService] Enviando solicitud de ingreso con código: $invitationCode');

    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    if (invitationCode.isEmpty) throw Exception('Código de invitación vacío');

    // Buscar el círculo por código — vía circleInvites (DT-RULES-CIRCLES-OPEN):
    // un no-miembro no puede leer/listar `circles` directamente bajo las
    // reglas nuevas, así que el lookup pasa por esta colección intermedia.
    final inviteDoc = await _firestore.collection('circleInvites').doc(invitationCode).get();
    if (!inviteDoc.exists) throw Exception('Código de invitación inválido');

    final circleId = inviteDoc.data()!['circleId'] as String;

    // Validación de membresía vía el propio doc del usuario (self-read, siempre
    // permitido) — leer circles/{circleId} aquí exigiría ya ser miembro
    // (DT-RULES-CIRCLES-OPEN), imposible antes de unirse. circleInvites/{code}
    // se borra cuando el círculo desaparece (leaveCircle/deleteAccount), así que
    // su sola existencia ya certifica que el círculo existe. MVP: un único
    // círculo por usuario, por lo que circleId propio == circleId del código
    // implica ya ser miembro de este círculo.
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final currentCircleId = userDoc.data()?['circleId'] as String?;
    if (currentCircleId == circleId) {
      throw Exception('Ya eres miembro de este círculo');
    }

    final existingPending = userDoc.data()?['pendingCircleId'] as String?;
    if (existingPending != null && existingPending.isNotEmpty) {
      throw Exception('Ya tienes una solicitud pendiente');
    }

    // ¿Tiene una solicitud activa (pending) en este círculo?
    final existingRequest =
        await _firestore.collection('circles').doc(circleId).collection('joinRequests').doc(user.uid).get();

    if (existingRequest.exists) {
      final status = existingRequest.data()?['status'] as String?;
      if (status == 'pending') {
        throw Exception('Ya tienes una solicitud pendiente en este círculo');
      }
      // status = 'approved' | 'expired' → se permite continuar (set sobreescribe)
    }

    // Obtener nickname y email del solicitante (desnormalización)
    final nickname = userDoc.data()?['nickname'] as String? ?? '';
    final email = user.email ?? '';

    // Batch: crear joinRequest + setear pendingCircleId
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('circles').doc(circleId).collection('joinRequests').doc(user.uid),
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
  Future<void> approveJoinRequest(String circleId, String requestingUserId) async {
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
    // NOTA (DT-RULES-CIRCLES-OPEN): el creador YA NO escribe users/{requestingUserId}
    // — las reglas nuevas exigen self-write. El propio solicitante detecta
    // el cambio de status vía listenToOwnJoinRequest() y escribe su circleId.

    await batch.commit();
    log('[CircleService] ✅ Solicitud aprobada para: $requestingUserId');
    _refreshController.add(null);
  }

  /// Rechaza la solicitud de ingreso de [requestingUserId] al [circleId].
  /// Solo el creador del círculo puede llamar a este método.
  Future<void> rejectJoinRequest(String circleId, String requestingUserId) async {
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
    // NOTA (DT-RULES-CIRCLES-OPEN): el creador YA NO limpia pendingCircleId
    // de otro usuario — self-write exigido por las reglas nuevas. El propio
    // solicitante lo limpia vía listenToOwnJoinRequest().

    await batch.commit();
    log('[CircleService] ✅ Solicitud rechazada para: $requestingUserId');
    _refreshController.add(null);
  }

  /// Escucha la PROPIA solicitud de ingreso pendiente y reacciona al veredicto
  /// del creador escribiendo el resultado en el propio documento de usuario.
  /// DT-RULES-CIRCLES-OPEN: el creador ya no puede escribir users/{otroUid}
  /// (self-write exigido por las reglas), así que quien detecta y aplica el
  /// cambio es el propio solicitante. Retorna la subscription para que el
  /// caller la cancele en dispose().
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> listenToOwnJoinRequest({
    required String circleId,
  }) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    return _firestore
        .collection('circles')
        .doc(circleId)
        .collection('joinRequests')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final status = snapshot.data()?['status'] as String?;

      if (status == 'approved') {
        // Guard contra reproceso: leaveCircle() no resetea este doc
        // joinRequests, que queda en 'approved' para siempre. Sin este check,
        // cualquier re-disparo del listener (p. ej. una escritura optimista
        // local revertida por el servidor) reescribe circleId aunque el
        // usuario ya haya salido del círculo. pendingCircleId solo está
        // presente mientras la aprobación no fue procesada todavía.
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.data()?['pendingCircleId'] != circleId) return;
        await _firestore.collection('users').doc(user.uid).update({
          'circleId': circleId,
          'pendingCircleId': FieldValue.delete(),
        });
        log('[CircleService] ✅ Solicitud propia aprobada — circleId escrito');
      } else if (status == 'rejected') {
        await _firestore.collection('users').doc(user.uid).update({
          'pendingCircleId': FieldValue.delete(),
        });
        log('[CircleService] ℹ️ Solicitud propia rechazada — pendingCircleId limpiado');
      }
    });
  }

  /// Stream de las solicitudes pendientes de ingreso a un círculo.
  /// Solo el creador debería suscribirse a este stream.
  /// Aplica expiración lazy: solicitudes con más de 48h se marcan "expired"
  /// en Firestore y se excluyen del resultado.
  Stream<List<JoinRequest>> getPendingJoinRequestsStream(String circleId) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .collection('joinRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final active = <JoinRequest>[];
          for (final doc in snapshot.docs) {
            final request = JoinRequest.fromFirestore(doc);
            final age = request.requestedAt != null
                ? now.difference(request.requestedAt!)
                : Duration.zero;
            if (age.inHours >= 48) {
              // Expiración lazy: marcar en Firestore (fire-and-forget)
              doc.reference.update({'status': 'expired'}).catchError((_) {});
              log('[CircleService] ⏰ Solicitud expirada: ${request.userId}');
            } else {
              active.add(request);
            }
          }
          return active;
        });
  }

  /// Obtiene el círculo actual del usuario
  Future<Circle?> getUserCircle() async {
    final user = _auth.currentUser;
    if (user == null) {
      log('[CircleService] Usuario no autenticado');
      return null;
    }

    try {
      final userSnapshot = await _firestore.collection('users').doc(user.uid).get();

      if (!userSnapshot.exists) {
        log('[CircleService] Documento de usuario no existe');
        return null;
      }

      final circleId = userSnapshot.data()?['circleId'] as String?;

      if (circleId == null || circleId.isEmpty) {
        log('[CircleService] Usuario no tiene círculo asignado');
        return null;
      }

      final circleDoc = await _firestore.collection('circles').doc(circleId).get();

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
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? circleSubscription;
    StreamSubscription<void>? refreshSubscription;

    controller = StreamController<UserCircleState>(
      onListen: () {
        void processUserSnapshot(DocumentSnapshot<Map<String, dynamic>> userSnapshot) async {
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
            circleSubscription = _firestore.collection('circles').doc(circleId).snapshots().listen(
              (circleSnapshot) {
                if (!circleSnapshot.exists) {
                  log('[CircleService] Stream: Círculo eliminado');
                  // Limpiar circleId del propio usuario (escritura en doc propio — permitida por reglas)
                  _firestore.collection('users').doc(user.uid).update({
                    'circleId': FieldValue.delete(),
                  }).catchError((_) {}); // silencioso si el doc ya no existe
                  controller.add(UserNoCircle());
                  return;
                }
                final state = UserInCircle(Circle.fromFirestore(circleSnapshot));
                log('[CircleService] Stream: ✅ Círculo actualizado: ${state.circle.name}');
                controller.add(state);
              },
              onError: (e) {
                // DT-RULES-CIRCLES-OPEN: el write optimista (local) de circleId en
                // users/{uid} dispara este listener antes de que el batch de
                // createCircle()/approveJoinRequest() confirme en el servidor. Las
                // reglas (gate de membresía) deniegan esa lectura prematura — se
                // autocorrige con el forceRefresh() que ya dispara ese mismo método
                // al terminar. No propagar como excepción no manejada.
                log('[CircleService] Stream: circleSubscription error (carrera post-escritura esperada): $e');
              },
            );
          } else if (pendingCircleId != null && pendingCircleId.isNotEmpty) {
            // Verificar si la solicitud sigue pendiente o ya expiró
            log('[CircleService] Stream: Verificando solicitud pendiente en $pendingCircleId');
            await circleSubscription?.cancel();
            circleSubscription = null;
            try {
              final joinRequestDoc = await _firestore
                  .collection('circles')
                  .doc(pendingCircleId)
                  .collection('joinRequests')
                  .doc(user.uid)
                  .get();
              final status = joinRequestDoc.data()?['status'] as String?;
              if (status == 'expired' || !joinRequestDoc.exists) {
                // Solicitud expirada: limpiar pendingCircleId del propio doc
                log('[CircleService] Stream: Solicitud expirada — limpiando pendingCircleId');
                _firestore.collection('users').doc(user.uid).update({
                  'pendingCircleId': FieldValue.delete(),
                }).catchError((_) {});
                controller.add(UserNoCircle());
              } else {
                controller.add(UserPendingRequest(pendingCircleId));
              }
            } catch (e) {
              log('[CircleService] Stream: Error verificando joinRequest: $e');
              controller.add(UserPendingRequest(pendingCircleId));
            }
          } else {
            // Sin círculo
            log('[CircleService] Stream: Usuario sin círculo');
            await circleSubscription?.cancel();
            circleSubscription = null;
            controller.add(UserNoCircle());
          }
        }

        // Escuchar cambios en el documento del usuario
        userSubscription = _firestore.collection('users').doc(user.uid).snapshots().listen(
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
          final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
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

  // ════════════════════════════════════════════════════════════
  // [FIX] Source.cache primero para getUserDoc
  // Fecha: 2026-05-14
  // PROBLEMA: .get() sin Source.cache siempre iba a servidor (~6s en red fría),
  //   bloqueando _getAllMemberNicknames() en InCircleView.
  // SOLUCIÓN: intentar cache local primero (0ms si existe); si no, servidor.
  // ════════════════════════════════════════════════════════════
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid) async {
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
    } on FirebaseException {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
    }
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
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      if (!userDoc.exists || userData == null || !userData.containsKey('circleId')) {
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

        final members = List<String>.from(circleDoc.data()!['members'] ?? []);
        final creatorId = circleDoc.data()!['creatorId'] as String?;
        final isCreator = creatorId != null && creatorId == user.uid;

        // Verificar que el usuario esté realmente en el círculo
        if (!members.contains(user.uid)) {
          throw Exception('El usuario no está en este círculo');
        }

        // Remover al usuario de la lista de miembros
        members.remove(user.uid);

        // Si es el último miembro, eliminar el círculo completamente
        if (members.isEmpty) {
          // Borrar circleInvites ANTES que el círculo — misma razón que en
          // deleteAccount(): la regla de borrado de circleInvites exige
          // get(circles/{circleId}).data.creatorId (DT-RULES-CIRCLES-OPEN).
          final invitationCode = circleDoc.data()!['invitation_code'] as String?;
          if (invitationCode != null && invitationCode.isNotEmpty) {
            transaction.delete(_firestore.collection('circleInvites').doc(invitationCode));
          }
          transaction.delete(circleRef);
          log('[CircleService] Círculo eliminado (último miembro salió)');
        } else if (isCreator) {
          // Sucesión automática (estilo WhatsApp): el miembro más antiguo
          // sobreviviente (members[0], preserva orden de arrayUnion) asume
          // el rol de Creador. Sin diálogo de elección.
          final newCreatorId = members.first;
          transaction.update(circleRef, {
            'members': members,
            'creatorId': newCreatorId,
          });
          log('[CircleService] Creador salió. Nuevo creador: $newCreatorId. Miembros restantes: ${members.length}');
        } else {
          // Actualizar la lista de miembros del círculo
          transaction.update(circleRef, {'members': members});
          log('[CircleService] Usuario removido del círculo. Miembros restantes: ${members.length}');
        }

        // Remover circleId del documento del usuario
        transaction.update(_firestore.collection('users').doc(user.uid), {
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
    if (kDebugMode) {
      log('[CircleService] 🗑️ Iniciando deleteAccount() para uid: $uid');
    }

    // 1. Manejar círculo según rol (creador vs miembro común)
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId != null && circleId.isNotEmpty) {
        log('[CircleService] 🔍 Usuario pertenece al círculo: $circleId');
        final circleDoc = await _firestore.collection('circles').doc(circleId).get();
        if (circleDoc.exists) {
          final creatorId = circleDoc.data()?['creatorId'] as String? ?? '';
          if (uid == creatorId) {
            // Es el creador: eliminar el círculo.
            // Cada miembro limpiará su propio circleId cuando su stream
            // detecte que el círculo ya no existe (getUserCircleStream).
            log('[CircleService] 👑 Usuario es creador, eliminando círculo...');
            // Primero limpiar subcolección joinRequests (Firestore no la borra automáticamente)
            log('[CircleService] 🗑️ Limpiando subcolección joinRequests...');
            final joinRequestsSnapshot = await _firestore
                .collection('circles')
                .doc(circleId)
                .collection('joinRequests')
                .get();
            if (joinRequestsSnapshot.docs.isNotEmpty) {
              final batch = _firestore.batch();
              for (final doc in joinRequestsSnapshot.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              log('[CircleService] ✅ joinRequests eliminados: ${joinRequestsSnapshot.docs.length}');
            }
            // Borrar circleInvites ANTES que el círculo: su regla de borrado
            // exige get(circles/{circleId}).data.creatorId — si el círculo ya
            // no existe, ese get() no resuelve y la regla deniega, dejando
            // circleInvites huérfano y abortando el resto de deleteAccount()
            // (DT-RULES-CIRCLES-OPEN).
            final invitationCode = circleDoc.data()?['invitation_code'] as String?;
            if (invitationCode != null && invitationCode.isNotEmpty) {
              await _firestore.collection('circleInvites').doc(invitationCode).delete();
              log('[CircleService] ✅ circleInvites/$invitationCode eliminado.');
            }
            // Luego borrar el documento del círculo
            await _firestore.collection('circles').doc(circleId).delete();
            log('[CircleService] ✅ Círculo eliminado por su creador.');
          } else {
            // Es miembro común: solo salir del círculo (sin transacción para evitar deadlock)
            log('[CircleService] 👤 Usuario es miembro, saliendo del círculo...');
            try {
              final members = List<String>.from(circleDoc.data()!['members'] ?? []);
              members.remove(uid);
              await _firestore.collection('circles').doc(circleId).update({
                'members': members,
              });
              log('[CircleService] ✅ Usuario removido del círculo.');
            } catch (e) {
              log('[CircleService] ⚠️ Error removiendo del círculo (continuando): $e');
            }
          }
        }
      }

      // Limpiar pendingCircleId si existe
      final pendingCircleId = userDoc.data()?['pendingCircleId'] as String?;
      if (pendingCircleId != null && pendingCircleId.isNotEmpty) {
        log('[CircleService] 🔄 Limpiando pendingCircleId...');
        try {
          await _firestore
              .collection('circles')
              .doc(pendingCircleId)
              .collection('joinRequests')
              .doc(uid)
              .update({'status': 'cancelled'});
        } catch (e) {
          log('[CircleService] ⚠️ Error limpiando pendingCircleId (continuando): $e');
        }
      }
    }

    // 2. Borrar documento del usuario en Firestore PRIMERO
    // (request.auth sigue válido aquí; la sesión todavía existe)
    log('[CircleService] 🗑️ Eliminando documento de usuario...');
    await _firestore.collection('users').doc(uid).delete();
    log('[CircleService] ✅ Documento de usuario eliminado.');

    // 3. Borrar cuenta de Firebase Auth
    // Si la sesión no es reciente, lanza requires-recent-login.
    log('[CircleService] 🔐 Eliminando cuenta de Firebase Auth...');
    await user.delete();
    log('[CircleService] ✅ Cuenta de Firebase Auth eliminada.');
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
