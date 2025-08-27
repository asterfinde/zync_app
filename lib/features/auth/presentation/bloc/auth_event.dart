// lib/features/auth/presentation/bloc/auth_event.dart

part of 'auth_bloc.dart';

// CORRECCIÓN: Añadida la importación para @immutable.
// import 'package:meta/meta.dart';

@immutable
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class SignInOrRegisterEvent extends AuthEvent {
  final String email;
  final String password;

  const SignInOrRegisterEvent({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class SignOutEvent extends AuthEvent {
  const SignOutEvent();
}

class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}