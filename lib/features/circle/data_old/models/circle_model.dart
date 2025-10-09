// lib/features/circle/data/models/circle_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/features/auth/domain/entities/user.dart';
import 'package:zync_app/features/circle/domain/entities/circle.dart' as circle_entity;
import 'package:zync_app/features/circle/data/models/user_status_model.dart';
import 'package:zync_app/features/auth/data/models/user_model.dart';

class CircleModel extends circle_entity.Circle {
  const CircleModel({
    required super.id,
    required super.name,
    required super.invitationCode,
    required super.members,
    required Map<String, UserStatusModel> super.memberStatus,
  }) : super();

  static Future<CircleModel> fromSnapshot(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    
    final statusData = data['memberStatus'] as Map<String, dynamic>? ?? {};
    final memberStatusMap = statusData.map((key, value) {
      return MapEntry(key, UserStatusModel.fromMap(value as Map<String, dynamic>, key));
    });

    final List<String> memberUIDs = List<String>.from(data['members'] ?? []);
    final List<User> hydratedMembers = [];

    if (memberUIDs.isNotEmpty) {
      final userFutures = memberUIDs.map((uid) {
        return FirebaseFirestore.instance.collection('users').doc(uid).get();
      }).toList();
      
      final userSnapshots = await Future.wait(userFutures);
      
      for (var userDoc in userSnapshots) {
        if (userDoc.exists) {
          hydratedMembers.add(UserModel.fromSnapshot(userDoc));
        }
      }
    }

    return CircleModel(
      id: doc.id,
      name: data['name'] ?? '',
      invitationCode: data['invitation_code'] ?? '',
      memberStatus: memberStatusMap,
      members: hydratedMembers,
    );
  }
  
  // Este método ahora compilará sin errores porque UserStatusModel ya tiene .toEntity()
  circle_entity.Circle toEntity() {
    final entityStatusMap = (memberStatus as Map<String, UserStatusModel>)
        .map((key, model) => MapEntry(key, model.toEntity()));

    return circle_entity.Circle(
      id: id,
      name: name,
      invitationCode: invitationCode,
      members: members,
      memberStatus: entityStatusMap,
    );
  }

  Map<String, dynamic> toJson() {
    final firestoreStatusMap = (memberStatus as Map<String, UserStatusModel>)
        .map((key, model) => MapEntry(key, model.toMap()));

    return {
      'name': name,
      'invitation_code': invitationCode,
      'members': members.map((user) => user.uid).toList(),
      'memberStatus': firestoreStatusMap,
    };
  }

  CircleModel copyWith({
    String? id,
    String? name,
    String? invitationCode,
    List<User>? members,
    Map<String, UserStatusModel>? memberStatus,
  }) {
    return CircleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      invitationCode: invitationCode ?? this.invitationCode,
      members: members ?? this.members,
      memberStatus: memberStatus ?? this.memberStatus as Map<String, UserStatusModel>,
    );
  }
}