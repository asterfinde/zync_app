import 'package:equatable/equatable.dart';
import 'package:zync_app/features/auth/domain/entities/user.dart';

class Circle extends Equatable {
  final String id;
  final String name;
  final String invitationCode;
  final List<User> members;
  final Map<String, String> memberStatus;

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
