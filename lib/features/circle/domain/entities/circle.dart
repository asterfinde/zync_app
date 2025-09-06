// lib/features/circle/domain/entities/circle.dart

import 'package:equatable/equatable.dart';
import 'package:zync_app/features/auth/domain/entities/user.dart';
import 'package:zync_app/features/circle/domain/entities/user_status.dart';

class Circle extends Equatable {
  final String id;
  final String name;
  final String invitationCode;
  final List<User> members;
  final Map<String, UserStatus> memberStatus;

  const Circle({
    required this.id,
    required this.name,
    required this.invitationCode,
    required this.members,
    required this.memberStatus,
  });

  @override
  List<Object?> get props => [id, name, invitationCode, members, memberStatus];
}