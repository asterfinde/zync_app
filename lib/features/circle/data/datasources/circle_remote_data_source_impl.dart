import 'dart:developer'; // Añadido para logging
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/core/error/exceptions.dart';
import 'package:zync_app/features/auth/data/models/user_model.dart';
import 'package:zync_app/features/circle/data/models/circle_model.dart';
import 'circle_remote_data_source.dart';

class CircleRemoteDataSourceImpl implements CircleRemoteDataSource {
  final FirebaseFirestore _firestore;
  CircleRemoteDataSourceImpl(this._firestore);

  @override
  Stream<CircleModel?> getCircleStreamForUser(String userId) {
    log("[CircleDataSource] HU: Creando stream para buscar círculo con 'members' que contenga a $userId...");
    return _firestore
        .collection('circles')
        .where('members', arrayContains: userId)
        .limit(1)
        .snapshots()
        .map((querySnapshot) {
      if (querySnapshot.docs.isEmpty) {
        log("[CircleDataSource] HU: La consulta no encontró círculos para $userId.");
        return null;
      }
      log("[CircleDataSource] HU: La consulta encontró el círculo ${querySnapshot.docs.first.id}.");
      return CircleModel.fromSnapshot(querySnapshot.docs.first);
    });
  }

  @override
  Future<void> createCircle(String? name, UserModel creator) async {
    if (name == null || name.isEmpty) {
      throw ServerException(message: 'Circle name cannot be empty');
    }
    
    final newCircleRef = _firestore.collection('circles').doc();
    final userRef = _firestore.collection('users').doc(creator.uid);
    final invitationCode = newCircleRef.id.substring(0, 6).toUpperCase();

    final newCircleData = {
      'name': name,
      'invitation_code': invitationCode,
      'members': [creator.uid],
      'memberStatus': {creator.uid: '😊'},
    };

    final batch = _firestore.batch();
    log("[CircleDataSource] HU: Añadiendo creación de círculo y actualización de usuario al batch...");
    batch.set(newCircleRef, newCircleData);
    batch.update(userRef, {'circleId': newCircleRef.id});
    await batch.commit();
    log("[CircleDataSource] HU: Batch de creación de círculo completado.");
  }
  
  @override
  Future<DocumentSnapshot> getCircleDocument(String circleId) async {
    log("[CircleDataSource] HU: Obteniendo documento del círculo $circleId...");
    return _firestore.collection('circles').doc(circleId).get();
  }

  @override
  Future<void> joinCircle(String? invitationCode, String? userId) async {
    if (invitationCode == null || invitationCode.isEmpty) {
      throw ServerException(message: 'Invitation code cannot be empty');
    }
    if (userId == null || userId.isEmpty) {
      throw ServerException(message: 'User ID cannot be empty');
    }

    log("[CircleDataSource] HU: Buscando círculo con código de invitación $invitationCode...");
    final query = await _firestore.collection('circles').where('invitation_code', isEqualTo: invitationCode).limit(1).get();
    if (query.docs.isEmpty) {
      log("[CircleDataSource] HU: FALLO, no se encontró ningún círculo con ese código.");
      throw ServerException(message: 'Invalid invitation code.');
    }
    
    final circleRef = query.docs.first.reference;
    final userRef = _firestore.collection('users').doc(userId);

    log("[CircleDataSource] HU: Círculo ${circleRef.id} encontrado. Iniciando transacción para unir al usuario $userId...");
    await _firestore.runTransaction((transaction) async {
      final circleSnapshot = await transaction.get(circleRef);
      if (!circleSnapshot.exists) {
        throw ServerException(message: 'Circle does not exist.');
      }

      final List<String> currentMembers = List<String>.from(circleSnapshot.get('members') ?? []);
      log("[CircleDataSource] HU: Miembros actuales en la transacción: $currentMembers");

      if (currentMembers.contains(userId)) {
        log("[CircleDataSource] HU: FALLO, el usuario ya es miembro.");
        throw ServerException(message: 'You are already a member of this circle.');
      }
      
      currentMembers.add(userId);
      log("[CircleDataSource] HU: Miembros actualizados en la transacción: $currentMembers");
      
      transaction.update(circleRef, {
        'members': currentMembers,
        'memberStatus.$userId': '😊',
      });
      
      transaction.update(userRef, {'circleId': circleRef.id});
    });
    log("[CircleDataSource] HU: Transacción para unirse completada con éxito.");
  }

  // El resto del archivo no necesita logs para este caso de prueba.
  // ...
  @override
  Future<void> updateCircleStatus(String? circleId, String? userId, String? newStatusEmoji) async {
    if (circleId == null || circleId.isEmpty) throw ServerException(message: 'Circle ID cannot be empty');
    if (userId == null || userId.isEmpty) throw ServerException(message: 'User ID cannot be empty');
    if (newStatusEmoji == null || newStatusEmoji.isEmpty) throw ServerException(message: 'Status cannot be empty');
    
    await _firestore.collection('circles').doc(circleId).update({
      'memberStatus.$userId': newStatusEmoji,
    });
  }
}


// // lib/features/circle/data/datasources/circle_remote_data_source_impl.dart

// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:zync_app/core/error/exceptions.dart';
// import 'package:zync_app/features/auth/data/models/user_model.dart';
// import 'package:zync_app/features/circle/data/models/circle_model.dart';
// import 'circle_remote_data_source.dart';

// class CircleRemoteDataSourceImpl implements CircleRemoteDataSource {
//   final FirebaseFirestore _firestore;
//   CircleRemoteDataSourceImpl(this._firestore);

//   @override
//   Stream<CircleModel?> getCircleStreamForUser(String userId) {
//     // CORRECCIÓN DEFINITIVA: Se cambia la lógica para que sea más robusta.
//     // En lugar de leer el documento del usuario, hacemos una consulta directa
//     // a la colección de círculos.
//     return _firestore
//         .collection('circles')
//         .where('members', arrayContains: userId)
//         .limit(1)
//         .snapshots()
//         .map((querySnapshot) {
//       if (querySnapshot.docs.isEmpty) {
//         // Si no se encuentra ningún círculo, el usuario no está en uno.
//         return null;
//       }
//       // Si se encuentra un círculo, se convierte a nuestro modelo.
//       return CircleModel.fromSnapshot(querySnapshot.docs.first);
//     });
//   }

//   @override
//   Future<void> createCircle(String name, UserModel creator) async {
//     final newCircleRef = _firestore.collection('circles').doc();
//     final userRef = _firestore.collection('users').doc(creator.uid);
//     final invitationCode = newCircleRef.id.substring(0, 6).toUpperCase();

//     final newCircleData = {
//       'name': name,
//       'invitation_code': invitationCode,
//       'members': [creator.uid],
//       'memberStatus': {creator.uid: '😊'},
//     };

//     final batch = _firestore.batch();
//     batch.set(newCircleRef, newCircleData);
//     batch.update(userRef, {'circleId': newCircleRef.id});
//     await batch.commit();
//   }
  
//   @override
//   Future<DocumentSnapshot> getCircleDocument(String circleId) async {
//     return _firestore.collection('circles').doc(circleId).get();
//   }

//   @override
//   Future<void> joinCircle(String invitationCode, String userId) async {
//     final query = await _firestore
//         .collection('circles')
//         .where('invitation_code', isEqualTo: invitationCode)
//         .limit(1)
//         .get();
//     if (query.docs.isEmpty) {
//       throw ServerException(message: 'Invalid invitation code.');
//     }

//     final circleRef = query.docs.first.reference;
//     final userRef = _firestore.collection('users').doc(userId);

//     await _firestore.runTransaction((transaction) async {
//       final circleSnapshot = await transaction.get(circleRef);
//       if (!circleSnapshot.exists) {
//         throw ServerException(message: 'Circle does not exist.');
//       }

//       final List<String> currentMembers =
//           List<String>.from(circleSnapshot.get('members') ?? []);

//       if (currentMembers.contains(userId)) {
//         throw ServerException(
//             message: 'You are already a member of this circle.');
//       }

//       currentMembers.add(userId);

//       transaction.update(circleRef, {
//         'members': currentMembers,
//         'memberStatus.$userId': '😊',
//       });

//       transaction.update(userRef, {'circleId': circleRef.id});
//     });
//   }

//   @override
//   Future<void> updateCircleStatus(
//       String circleId, String userId, String newStatusEmoji) async {
//     await _firestore.collection('circles').doc(circleId).update({
//       'memberStatus.$userId': newStatusEmoji,
//     });
//   }
// }


// // // lib/features/circle/data/datasources/circle_remote_data_source_impl.dart

// // import 'dart:async';
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:zync_app/core/error/exceptions.dart';
// // import 'package:zync_app/features/auth/data/models/user_model.dart';
// // import 'package:zync_app/features/circle/data/models/circle_model.dart';
// // import 'circle_remote_data_source.dart';

// // class CircleRemoteDataSourceImpl implements CircleRemoteDataSource {
// //   final FirebaseFirestore _firestore;
// //   CircleRemoteDataSourceImpl(this._firestore);

// //   @override
// //   Future<void> createCircle(String name, UserModel creator) async {
// //     final newCircleRef = _firestore.collection('circles').doc();
// //     final userRef = _firestore.collection('users').doc(creator.uid);
// //     final invitationCode = newCircleRef.id.substring(0, 6).toUpperCase();

// //     final newCircleData = {
// //       'name': name,
// //       'invitation_code': invitationCode,
// //       'members': [creator.uid],
// //       'memberStatus': {creator.uid: '😊'},
// //     };

// //     final batch = _firestore.batch();
// //     batch.set(newCircleRef, newCircleData);
// //     batch.update(userRef, {'circleId': newCircleRef.id});
// //     await batch.commit();
// //   }

// //   @override
// //   Stream<CircleModel?> getCircleStreamForUser(String userId) {
// //     return _firestore
// //         .collection('users')
// //         .doc(userId)
// //         .snapshots()
// //         .asyncMap((userSnap) async {
// //       if (!userSnap.exists || userSnap.data() == null) return null;
// //       final circleId = userSnap.data()!['circleId'] as String?;
// //       if (circleId == null || circleId.isEmpty) return null;

// //       final circleSnap = await getCircleDocument(circleId);
// //       if (!circleSnap.exists) return null;

// //       return CircleModel.fromSnapshot(circleSnap);
// //     });
// //   }

// //   @override
// //   Future<DocumentSnapshot> getCircleDocument(String circleId) async {
// //     return _firestore.collection('circles').doc(circleId).get();
// //   }

// //   @override
// //   Future<void> joinCircle(String invitationCode, String userId) async {
// //     final query = await _firestore
// //         .collection('circles')
// //         .where('invitation_code', isEqualTo: invitationCode)
// //         .limit(1)
// //         .get();
// //     if (query.docs.isEmpty) {
// //       throw ServerException(message: 'Invalid invitation code.');
// //     }

// //     final circleRef = query.docs.first.reference;
// //     final userRef = _firestore.collection('users').doc(userId);

// //     print('[joinCircle] UID usado en la transacción: $userId');
// //     await _firestore.runTransaction((transaction) async {
// //       final circleSnapshot = await transaction.get(circleRef);
// //       if (!circleSnapshot.exists) {
// //         throw ServerException(message: 'Circle does not exist.');
// //       }

// //       final List<String> currentMembers =
// //           List<String>.from(circleSnapshot.get('members') ?? []);
// //       print('[joinCircle] Miembros antes de la transacción: $currentMembers');

// //       if (currentMembers.contains(userId)) {
// //         throw ServerException(
// //             message: 'You are already a member of this circle.');
// //       }

// //       currentMembers.add(userId);
// //       print('[joinCircle] Miembros después de la transacción: $currentMembers');

// //       transaction.update(circleRef, {
// //         'members': currentMembers,
// //         'memberStatus.$userId': '😊',
// //       });

// //       transaction.update(userRef, {'circleId': circleRef.id});
// //     });
// //   }

// //   @override
// //   Future<void> updateCircleStatus(
// //       String circleId, String userId, String newStatusEmoji) async {
// //     await _firestore.collection('circles').doc(circleId).update({
// //       'memberStatus.$userId': newStatusEmoji,
// //     });
// //   }
// // }

