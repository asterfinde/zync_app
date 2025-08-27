// lib/features/auth/presentation/bloc/auth_state.dart  

part of 'auth_bloc.dart';

@immutable
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// El estado inicial, antes de que se haya verificado la autenticación.
class AuthInitial extends AuthState {}

/// Indica que una operación de autenticación está en progreso.
class AuthLoading extends AuthState {}

/// Indica que el usuario está autenticado exitosamente y contiene los datos del usuario.
class Authenticated extends AuthState {
  final User user;

  const Authenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

/// Indica que no hay ningún usuario autenticado.
class Unauthenticated extends AuthState {}

/// Indica que ocurrió un error durante el proceso de autenticación.
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}