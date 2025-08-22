// lib/features/auth/presentation/bloc/auth_event.dart

part of 'auth_bloc.dart';

@immutable
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

/// Evento que se dispara cuando el usuario intenta iniciar sesión o registrarse.
class SignInOrRegisterEvent extends AuthEvent {
  final String email;
  final String password;

  const SignInOrRegisterEvent({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

/// Evento que se dispara para cerrar la sesión del usuario.
class SignOutEvent extends AuthEvent {
  const SignOutEvent();
}

/// Evento para verificar si ya existe un usuario autenticado al iniciar la app.
class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}
