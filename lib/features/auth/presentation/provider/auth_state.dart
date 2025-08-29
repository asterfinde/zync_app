import 'package:equatable/equatable.dart'; // <-- LÍNEA CORREGIDA
import '../../domain/entities/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

/// Estado inicial, la app no sabe si el usuario está logueado.
class AuthInitial extends AuthState {}

/// Estado de carga, mientras se procesa el login/logout.
class AuthLoading extends AuthState {}

/// Estado cuando el usuario está autenticado.
class Authenticated extends AuthState {
  final User user;
  const Authenticated(this.user);
  @override
  List<Object?> get props => [user];
}

/// Estado cuando el usuario NO está autenticado.
class Unauthenticated extends AuthState {}

/// Estado para manejar cualquier error durante el proceso.
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}