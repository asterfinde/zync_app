// lib/features/circle/data/datasources/circle_remote_data_source.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/features/circle/data/models/circle_model.dart';
import 'package:zync_app/features/circle/domain/entities/user_status.dart';

abstract class CircleRemoteDataSource {
  Stream<CircleModel?> getCircleStreamForUser(String userId);

  Future<DocumentSnapshot> getCircleDocument(String circleId);

  // Unificado a creatorId String (el repo provee FirebaseAuth.uid)
  Future<void> createCircle(String name, String creatorId);

  Future<void> joinCircle(String invitationCode, String userId);

  Future<CircleModel> getCircleByCreatorId(String creatorId);

  // Contrato de envío de estado
  Future<void> sendUserStatus({
    required String circleId,
    required String userId,
    required StatusType statusType,
    Coordinates? coordinates,
  });
}

// // lib/features/circle/data/datasources/circle_remote_data_source.dart

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:zync_app/features/auth/data/models/user_model.dart';
// import 'package:zync_app/features/circle/data/models/circle_model.dart';
// // ¡IMPORTANTE! Importamos las entidades del dominio para usarlas en la firma del método
// import 'package:zync_app/features/circle/domain/entities/user_status.dart';

// abstract class CircleRemoteDataSource {
//   Stream<CircleModel?> getCircleStreamForUser(String userId);

//   Future<DocumentSnapshot> getCircleDocument(String circleId);

//   Future<void> createCircle(String name, UserModel creator);

//   Future<void> joinCircle(String invitationCode, String userId);

//   Future<CircleModel> getCircleByCreatorId(String creatorId);

//   // 1. ELIMINAMOS el método antiguo y obsoleto
//   // Future<void> updateCircleStatus(String circleId, String userId, String newStatusEmoji);

//   // 2. AÑADIMOS el nuevo contrato que el Repository espera
//   Future<void> sendUserStatus({
//     required String circleId,
//     required String userId,
//     required StatusType statusType,
//     Coordinates? coordinates,
//   });
// }
