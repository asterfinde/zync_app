// lib/features/auth/domain/entities/user.dart

import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String uid;
  final String email;
  final String name;
  final String nickname;

  const User({
    required this.uid,
    required this.email,
    required this.name,
    required this.nickname,
  });

  @override
  List<Object?> get props => [uid, email, name, nickname];
}
