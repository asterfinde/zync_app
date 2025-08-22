// features/auth/presentation/bloc/auth_state.dart

part of 'auth_bloc.dart';

@immutable
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

/// Estado inicial, la app no sabe si el usuario está autenticado.
class AuthInitial extends AuthState {}

/// Estado de carga, se muestra mientras se realiza una operación asíncrona (ej. login).
class AuthLoading extends AuthState {}

/// Estado que indica que el usuario está autenticado correctamente.
/// Contiene la información del usuario.
class Authenticated extends AuthState {
  final User user;

  const Authenticated({required this.user});

  @override
  List<Object> get props => [user];
}

/// Estado que indica que no hay un usuario autenticado.
class Unauthenticated extends AuthState {}

/// Estado que representa un error durante una operación de autenticación.
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object> get props => [message];
}
