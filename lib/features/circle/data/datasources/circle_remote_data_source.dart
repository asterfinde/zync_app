// lib/features/circle/data/datasources/circle_remote_data_source.dart

import 'package:cloud_firestore/cloud_firestore.dart';
// CORRECCIÓN: La capa de datos debe usar Modelos, no Entidades.
import 'package:zync_app/features/auth/data/models/user_model.dart'; 
import 'package:zync_app/features/circle/data/models/circle_model.dart';

abstract class CircleRemoteDataSource {
  Stream<CircleModel?> getCircleStreamForUser(String userId);
  
  Future<DocumentSnapshot> getCircleDocument(String circleId);
  
  // CORRECCIÓN: Se especifica que debe recibir un UserModel, no un User.
  // Esto hace que el "contrato" coincida con la implementación.
  Future<void> createCircle(String name, UserModel creator); 
  
  Future<void> joinCircle(String invitationCode, String userId);
  
  Future<void> updateCircleStatus(String circleId, String userId, String newStatusEmoji);
}

// // lib/features/circle/data/datasources/circle_remote_data_source.dart

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:zync_app/features/auth/domain/entities/user.dart';
// import 'package:zync_app/features/circle/data/models/circle_model.dart';

// abstract class CircleRemoteDataSource {
//   Stream<CircleModel?> getCircleStreamForUser(String userId);
//   Future<DocumentSnapshot> getCircleDocument(String circleId);
//   Future<void> createCircle(String name, User creator);
//   Future<void> joinCircle(String invitationCode, String userId);
//   Future<void> updateCircleStatus(String circleId, String userId, String newStatusEmoji);
// }