// lib/features/circle/services/firebase_circle_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Circle {
  final String id;
  final String name;
  final String invitationCode;
  final List<String> members;

  Circle({
    required this.id,
    required this.name,
    required this.invitationCode,
    required this.members,
  });

  factory Circle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Circle(
      id: doc.id,
      name: data['name'] ?? '',
      invitationCode: data['invitation_code'] ?? '',
      members: List<String>.from(data['members'] ?? []),
    );
  }
}

class FirebaseCircleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // StreamController para forzar actualizaciones
  static final StreamController<void> _refreshController = StreamController<void>.broadcast();

  /// Crea un nuevo círculo para el usuario actual
  Future<String> createCircle(String name) async {
    log('[FirebaseCircleService] Creando círculo: $name');
    
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
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
    };

    // Usar batch para operación atómica
    final batch = _firestore.batch();
    batch.set(circleRef, circleData);
    batch.update(_firestore.collection('users').doc(user.uid), {
      'circleId': circleRef.id
    });

    await batch.commit();
    log('[FirebaseCircleService] ✅ Círculo creado exitosamente: ${circleRef.id}');
    
    // Forzar actualización del stream
    _refreshController.add(null);
    
    return circleRef.id;
  }

  /// Une al usuario actual a un círculo existente usando código de invitación
  Future<void> joinCircle(String invitationCode) async {
    log('[FirebaseCircleService] Uniéndose al círculo con código: $invitationCode');
    
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

      final currentMembers = List<String>.from(circleSnapshot.get('members') ?? []);

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
      
    log('[FirebaseCircleService] ✅ Usuario se unió al círculo exitosamente');
  }

  /// Obtiene el círculo actual del usuario
  Future<Circle?> getUserCircle() async {
    final user = _auth.currentUser;
    if (user == null) {
      log('[FirebaseCircleService] Usuario no autenticado');
      return null;
    }

    try {
      final userSnapshot = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userSnapshot.exists) {
        log('[FirebaseCircleService] Documento de usuario no existe');
        return null;
      }

      final circleId = userSnapshot.data()?['circleId'] as String?;
      
      if (circleId == null || circleId.isEmpty) {
        log('[FirebaseCircleService] Usuario no tiene círculo asignado');
        return null;
      }

      final circleDoc = await _firestore.collection('circles').doc(circleId).get();
      
      if (!circleDoc.exists) {
        log('[FirebaseCircleService] Círculo no existe: $circleId');
        return null;
      }

      final circle = Circle.fromFirestore(circleDoc);
      log('[FirebaseCircleService] ✅ Círculo obtenido: ${circle.name}');
      return circle;
    } catch (e) {
      log('[FirebaseCircleService] Error obteniendo círculo: $e');
      return null;
    }
  }

  /// Stream SIMPLIFICADO para escuchar cambios en el círculo del usuario
  Stream<Circle?> getUserCircleStream() {
    final user = _auth.currentUser;
    if (user == null) {
      log('[FirebaseCircleService] Usuario no autenticado para stream');
      return Stream.value(null);
    }

    // Crear un StreamController para manejar manualmente las actualizaciones
    late StreamController<Circle?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? circleSubscription;
    StreamSubscription<void>? refreshSubscription;

    controller = StreamController<Circle?>(
      onListen: () {
        // Función para procesar cambios en el documento del usuario
        void processUserSnapshot(DocumentSnapshot<Map<String, dynamic>> userSnapshot) async {
          if (!userSnapshot.exists) {
            log('[FirebaseCircleService] Stream: Usuario no existe');
            controller.add(null);
            return;
          }

          final circleId = userSnapshot.data()?['circleId'] as String?;
          
          if (circleId == null || circleId.isEmpty) {
            log('[FirebaseCircleService] Stream: Usuario sin círculo');
            controller.add(null);
            return;
          }

          log('[FirebaseCircleService] Stream: Escuchando círculo $circleId');
          
          // Cancelar suscripción anterior del círculo si existe
          await circleSubscription?.cancel();
          
          // Escuchar cambios en el círculo
          circleSubscription = _firestore
              .collection('circles')
              .doc(circleId)
              .snapshots()
              .listen((circleSnapshot) {
            if (!circleSnapshot.exists) {
              log('[FirebaseCircleService] Stream: Círculo no existe');
              controller.add(null);
              return;
            }

            final circle = Circle.fromFirestore(circleSnapshot);
            log('[FirebaseCircleService] Stream: ✅ Círculo actualizado: ${circle.name}');
            controller.add(circle);
          });
        }

        // Escuchar cambios en el usuario
        userSubscription = _firestore
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen(processUserSnapshot);

        // Escuchar señales de refresh manual
        refreshSubscription = _refreshController.stream.listen((_) async {
          log('[FirebaseCircleService] Stream: Refresh manual activado');
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
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
    log('[FirebaseCircleService] Usuario saliendo del círculo');
    
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
        
        // Verificar que el usuario esté realmente en el círculo
        if (!members.contains(user.uid)) {
          throw Exception('El usuario no está en este círculo');
        }
        
        // Remover al usuario de la lista de miembros
        members.remove(user.uid);
        
        // Si es el último miembro, eliminar el círculo completamente
        if (members.isEmpty) {
          transaction.delete(circleRef);
          log('[FirebaseCircleService] Círculo eliminado (último miembro salió)');
        } else {
          // Actualizar la lista de miembros del círculo
          transaction.update(circleRef, {'members': members});
          log('[FirebaseCircleService] Usuario removido del círculo. Miembros restantes: ${members.length}');
        }
        
        // Remover circleId del documento del usuario
        transaction.update(_firestore.collection('users').doc(user.uid), {
          'circleId': FieldValue.delete(),
        });
      });

      // Forzar actualización del stream
      _refreshController.add(null);
      
      log('[FirebaseCircleService] Usuario salió del círculo exitosamente');
    } catch (e) {
      log('[FirebaseCircleService] Error al salir del círculo: $e');
      rethrow;
    }
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

