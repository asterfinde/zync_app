// lib/features/circle/data/repositories/circle_repository_impl.dart

import 'dart:developer';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:zync_app/core/error/exceptions.dart';
import 'package:zync_app/core/error/failures.dart';
import 'package:zync_app/features/auth/data/models/user_model.dart';
import 'package:zync_app/features/auth/domain/entities/user.dart';
import 'package:zync_app/features/circle/data/models/circle_model.dart';
import 'package:zync_app/features/circle/domain/entities/circle.dart';
import 'package:zync_app/features/circle/domain/repositories/circle_repository.dart';
import '../datasources/circle_remote_data_source.dart';

class CircleRepositoryImpl implements CircleRepository {
  final CircleRemoteDataSource remoteDataSource;
  final fb_auth.FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  CircleRepositoryImpl({
    required this.remoteDataSource,
    required this.firebaseAuth,
    required this.firestore,
  });

  String _getCurrentUserId() {
    final fbUser = firebaseAuth.currentUser;
    if (fbUser == null) {
      throw ServerException(message: 'Usuario no autenticado.');
    }
    return fbUser.uid;
  }

  @override
  Stream<Either<Failure, Circle?>> getCircleStreamForUser() {
    log('[CircleRepository] HU: Iniciando getCircleStreamForUser...');
    try {
      final userId = _getCurrentUserId();
      log("[CircleRepository] HU: Obteniendo stream del círculo para el usuario $userId.");
      return remoteDataSource.getCircleStreamForUser(userId).transform(
            StreamTransformer.fromHandlers(
              handleData: (CircleModel? model,
                  EventSink<Either<Failure, Circle?>> sink) async {
                if (model == null) {
                  log("[CircleRepository] HU: DataSource devolvió un modelo nulo (usuario sin círculo).");
                  sink.add(const Right(null));
                  return;
                }
                log("[CircleRepository] HU: DataSource devolvió CircleModel para '${model.name}'. Iniciando hidratación.");
                try {
                  final docRef =
                      await remoteDataSource.getCircleDocument(model.id);
                  final docData = docRef.data() as Map<String, dynamic>?;
                  final memberUids =
                      List<String>.from(docData?['members'] ?? []);
                  log("[CircleRepository] HU: UIDs a hidratar: $memberUids");

                  // Validación previa: ¿el usuario actual es miembro?
                  final currentUserId = _getCurrentUserId();
                  if (!memberUids.contains(currentUserId)) {
                    log("[CircleRepository] HU: El usuario actual ($currentUserId) no es miembro del círculo. Abortando hidratación.");
                    sink.add(Left(ServerFailure(
                        message:
                            'No tienes permisos para ver los miembros de este círculo.')));
                    return;
                  }

                  final List<User> members = [];
                  if (memberUids.isNotEmpty) {
                    final usersSnapshot = await firestore
                        .collection('users')
                        .where(FieldPath.documentId, whereIn: memberUids)
                        .get();
                    log("[CircleRepository] HU: Firestore devolvió ${usersSnapshot.docs.length} documentos para hidratar.");
                    for (var doc in usersSnapshot.docs) {
                      members.add(UserModel.fromSnapshot(doc));
                    }
                  }

                  final hydratedModel = model.copyWith(members: members);
                  log("[CircleRepository] HU: Hidratación completa. Enviando entidad Circle a la UI.");
                  sink.add(Right(hydratedModel.toEntity()));
                } catch (e) {
                  log("[CircleRepository] HU: FALLO en la hidratación: ${e.toString()}");
                  sink.add(Left(ServerFailure(
                      message:
                          'Failed to hydrate circle members: ${e.toString()}')));
                }
              },
              handleError: (error, stackTrace, sink) {
                log("[CircleRepository] HU: El stream del DataSource lanzó un ERROR: $error");
                sink.add(Left(ServerFailure(message: error.toString())));
              },
            ),
          );
    } on ServerException catch (e) {
      log("[CircleRepository] HU: FALLO al obtener usuario actual: ${e.message}");
      return Stream.value(Left(ServerFailure(message: e.message ?? '')));
    }
  }

  @override
  Future<Either<Failure, void>> createCircle(String name) async {
    log("[CircleRepository] HU: Iniciando createCircle con nombre: '$name'");
    try {
      log("[CircleRepository] HU: Llamando a remoteDataSource.createCircle...");
      final firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return Left(ServerFailure(message: 'User not authenticated.'));
      }
      final userModel = UserModel.fromFirebase(firebaseUser);
      await remoteDataSource.createCircle(name, userModel);
      log("[CircleRepository] HU: remoteDataSource.createCircle finalizado con éxito.");
      return const Right(null);
    } on ServerException catch (e) {
      log("[CircleRepository] HU: FALLO en createCircle: ${e.message}");
      return Left(ServerFailure(message: e.message ?? ''));
    }
  }

  @override
  Future<Either<Failure, void>> joinCircle(String invitationCode) async {
    final userId = _getCurrentUserId();
    log('[CircleRepository] HU: Iniciando joinCircle del usuario $userId al círculo con código $invitationCode');
    try {
      await remoteDataSource.joinCircle(invitationCode, userId);
      log('[CircleRepository] HU: remoteDataSource.joinCircle finalizado con éxito para $userId.');
      return const Right(null);
    } on ServerException catch (e) {
      log('[CircleRepository] HU: FALLO en joinCircle para $userId: ${e.message}');
      return Left(ServerFailure(message: e.message ?? ''));
    }
  }

  @override
  Future<Either<Failure, void>> updateCircleStatus(
      String circleId, String newStatusEmoji) async {
    log("[CircleRepository] HU: Iniciando updateCircleStatus para el círculo $circleId");
    try {
      final userId = _getCurrentUserId();
      await remoteDataSource.updateCircleStatus(
          circleId, userId, newStatusEmoji);
      log("[CircleRepository] HU: remoteDataSource.updateCircleStatus finalizado con éxito.");
      return const Right(null);
    } on ServerException catch (e) {
      log("[CircleRepository] HU: FALLO en updateCircleStatus: ${e.message}");
      return Left(ServerFailure(message: e.message ?? ''));
    }
  }
}

// // lib/features/circle/data/repositories/circle_repository_impl.dart

// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:dartz/dartz.dart';
// import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
// import 'package:zync_app/core/error/exceptions.dart';
// import 'package:zync_app/core/error/failures.dart';
// import 'package:zync_app/features/auth/data/models/user_model.dart';
// import 'package:zync_app/features/auth/domain/entities/user.dart';
// import 'package:zync_app/features/circle/data/models/circle_model.dart';
// import 'package:zync_app/features/circle/domain/entities/circle.dart';
// import 'package:zync_app/features/circle/domain/repositories/circle_repository.dart';
// import '../datasources/circle_remote_data_source.dart';

// class CircleRepositoryImpl implements CircleRepository {
//   final CircleRemoteDataSource remoteDataSource;
//   final fb_auth.FirebaseAuth firebaseAuth;
//   final FirebaseFirestore firestore;

//   CircleRepositoryImpl({
//     required this.remoteDataSource,
//     required this.firebaseAuth,
//     required this.firestore,
//   });

//   String _getCurrentUserId() {
//     final fbUser = firebaseAuth.currentUser;
//     if (fbUser == null) throw ServerException(message: 'User not authenticated.');
//     return fbUser.uid;
//   }

//   User _getCurrentUser() {
//     final fbUser = firebaseAuth.currentUser;
//     if (fbUser == null) throw ServerException(message: 'User not authenticated.');
//     return User(
//       uid: fbUser.uid,
//       email: fbUser.email ?? '',
//       name: fbUser.displayName ?? '',
//     );
//   }

//   @override
//   Stream<Either<Failure, Circle?>> getCircleStreamForUser() {
//     try {
//       final userId = _getCurrentUserId();
//       return remoteDataSource.getCircleStreamForUser(userId).transform(
//         StreamTransformer.fromHandlers(
//           handleData: (CircleModel? model, EventSink<Either<Failure, Circle?>> sink) async {
//             if (model == null) {
//               sink.add(const Right(null));
//               return;
//             }
//             try {
//               final docRef = await remoteDataSource.getCircleDocument(model.id);
//               final docData = docRef.data() as Map<String, dynamic>?;
//               final memberUids = List<String>.from(docData?['members'] ?? []);
              
//               final List<User> members = [];
//               if (memberUids.isNotEmpty) {
//                  final usersSnapshot = await firestore.collection('users').where(FieldPath.documentId, whereIn: memberUids).get();
//                  for (var doc in usersSnapshot.docs) {
//                    members.add(UserModel.fromSnapshot(doc));
//                  }
//               }
              
//               final hydratedModel = model.copyWith(members: members);
//               sink.add(Right(hydratedModel.toEntity()));
//             } catch (e) {
//                sink.add(Left(ServerFailure(message: 'Failed to hydrate circle members: ${e.toString()}')));
//             }
//           },
//           handleError: (error, stackTrace, sink) {
//             sink.add(Left(ServerFailure(message: error.toString())));
//           },
//         ),
//       );
//     } on ServerException catch (e) {
//       return Stream.value(Left(ServerFailure(message: e.message ?? 'Unknown error')));
//     }
//   }

//   @override
//   Future<Either<Failure, void>> createCircle(String name) async {
//     try {
//       // 1. Se obtiene la "receta" (la entidad User)
//       final currentUser = _getCurrentUser();
      
//       // 2. CORRECCIÓN: La receta se convierte en una "orden de ingredientes" (un UserModel)
//       final currentUserModel = UserModel(
//         uid: currentUser.uid, 
//         email: currentUser.email, 
//         name: currentUser.name
//       );

//       // 3. Se le pasa la "orden de ingredientes" al proveedor (DataSource), que es lo que espera.
//       await remoteDataSource.createCircle(name, currentUserModel);
//       return const Right(null);
//     } on ServerException catch (e) {
//       return Left(ServerFailure(message: e.message ?? 'Unknown error'));
//     }
//   }

//   @override
//   Future<Either<Failure, void>> joinCircle(String invitationCode) async {
//     try {
//       final userId = _getCurrentUserId();
//       await remoteDataSource.joinCircle(invitationCode, userId);
//       return const Right(null);
//     } on ServerException catch (e) {
//       return Left(ServerFailure(message: e.message ?? 'Unknown error'));
//     }
//   }

//   @override
//   Future<Either<Failure, void>> updateCircleStatus(String circleId, String newStatusEmoji) async {
//     try {
//       final userId = _getCurrentUserId();
//       await remoteDataSource.updateCircleStatus(circleId, userId, newStatusEmoji);
//       return const Right(null);
//     } on ServerException catch (e) {
//       return Left(ServerFailure(message: e.message ?? 'Unknown error'));
//     }
//   }
// }

