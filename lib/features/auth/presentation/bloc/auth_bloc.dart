// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_in_or_register.dart';
import '../../domain/usecases/sign_out.dart';

part 'auth_event.dart';
part 'auth_state.dart';

// Constantes para mensajes de error.
const String serverFailureMessage = 'Error del servidor';
const String networkFailureMessage = 'Error de conexión';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInOrRegister signInOrRegister;
  final SignOut signOut;
  final GetCurrentUser getCurrentUser;

  AuthBloc({
    required this.signInOrRegister,
    required this.signOut,
    required this.getCurrentUser,
  }) : super(AuthInitial()) {
    // Registro de los manejadores de eventos
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SignInOrRegisterEvent>(_onSignInOrRegister);
    on<SignOutEvent>(_onSignOut);
  }

  /// Maneja la verificación del estado de autenticación al iniciar la app.
  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    final failureOrUser = await getCurrentUser(NoParams());
    failureOrUser.fold(
      (failure) => emit(Unauthenticated()),
      (user) {
        // --- CORRECCIÓN DEFINITIVA ---
        // Si el usuario que llega del repositorio NO es nulo, estamos autenticados.
        if (user != null) {
          emit(Authenticated(user: user));
        } else {
          // Si el usuario es nulo, significa que no hay sesión activa.
          emit(Unauthenticated());
        }
      },
    );
  }

  /// Maneja el inicio de sesión o registro de un usuario.
  Future<void> _onSignInOrRegister(
    SignInOrRegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final failureOrUser = await signInOrRegister(
      SignInOrRegisterParams(email: event.email, password: event.password),
    );
    failureOrUser.fold(
      (failure) => emit(AuthError(message: _mapFailureToMessage(failure))),
      (user) => emit(Authenticated(user: user)),
    );
  }

  /// Maneja el cierre de sesión del usuario actual.
  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final failureOrVoid = await signOut(NoParams());
    failureOrVoid.fold(
      (failure) => emit(AuthError(message: _mapFailureToMessage(failure))),
      (_) => emit(Unauthenticated()),
    );
  }

  /// Convierte un objeto [Failure] a un mensaje de error legible para la UI.
  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.message ?? serverFailureMessage;
    } else if (failure is NetworkFailure) {
      return networkFailureMessage;
    } else {
      return 'Ocurrió un error inesperado';
    }
  }
}