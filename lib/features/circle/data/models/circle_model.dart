// lib/features/circle/data/models/circle_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/features/auth/domain/entities/user.dart';
import 'package:zync_app/features/circle/domain/entities/circle.dart' as circle_entity;

class CircleModel {
  final String id;
  final String name;
  final String invitationCode;
  final List<User> members;
  final Map<String, String> memberStatus;

  const CircleModel({
    required this.id,
    required this.name,
    required this.invitationCode,
    required this.members,
    required this.memberStatus,
  });

  factory CircleModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CircleModel(
      id: doc.id,
      name: data['name'] ?? '',
      invitationCode: data['invitation_code'] ?? '',
      memberStatus: Map<String, String>.from(data['memberStatus'] ?? {}),
      members: const [], // Se inicia vacío, se llenará en el repositorio
    );
  }

  circle_entity.Circle toEntity() {
    return circle_entity.Circle(
      id: id,
      name: name,
      invitationCode: invitationCode,
      members: members,
      memberStatus: memberStatus,
    );
  }

  // CORRECCIÓN: Se reintroduce el método toJson() que es vital para escribir en Firestore.
  // Convierte la lista de miembros de objetos User a una lista de UIDs (String).
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'invitation_code': invitationCode,
      'members': members.map((user) => user.uid).toList(),
      'memberStatus': memberStatus,
    };
  }

  CircleModel copyWith({ List<User>? members }) {
    return CircleModel(
      id: id,
      name: name,
      invitationCode: invitationCode,
      members: members ?? this.members,
      memberStatus: memberStatus,
    );
  }
}