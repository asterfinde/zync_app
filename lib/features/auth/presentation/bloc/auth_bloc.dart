// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_in_or_register.dart';
import '../../domain/usecases/sign_out.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/error/failures.dart';

part 'auth_event.dart';
part 'auth_state.dart';

const String SERVER_FAILURE_MESSAGE = 'Server Failure';
const String NETWORK_FAILURE_MESSAGE = 'Network Failure';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInOrRegister signInOrRegister;
  final SignOut signOut;
  final GetCurrentUser getCurrentUser;

  AuthBloc({
    required this.signInOrRegister,
    required this.signOut,
    required this.getCurrentUser,
  }) : super(AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SignInOrRegisterEvent>(_onSignInOrRegister);
    on<SignOutEvent>(_onSignOut);
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final failureOrUser = await getCurrentUser(NoParams());
    failureOrUser.fold(
      (failure) => emit(Unauthenticated()),
      (user) => emit(Authenticated(user: user)),
    );
  }

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

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return (failure as ServerFailure).message ?? SERVER_FAILURE_MESSAGE;
      case NetworkFailure:
        return NETWORK_FAILURE_MESSAGE;
      default:
        return 'Unexpected Error';
    }
  }
}
