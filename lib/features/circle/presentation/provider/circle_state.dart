import 'package:equatable/equatable.dart';
import '../../domain/entities/circle.dart';

abstract class CircleState extends Equatable {
  const CircleState();
  @override
  List<Object> get props => [];
}

/// Estado inicial, antes de que se haya cargado nada.
class CircleInitial extends CircleState {}

/// Estado mientras se realiza una operación (crear, unirse, cargar).
class CircleLoading extends CircleState {}

/// Estado que indica que el usuario no pertenece a ningún círculo.
class NoCircle extends CircleState {}

/// Estado que indica que el usuario está en un círculo y tenemos sus datos.
class InCircle extends CircleState {
  final Circle circle;

  const InCircle(this.circle);

  @override
  List<Object> get props => [circle];
}

/// Estado que representa un error durante una operación.
class CircleError extends CircleState {
  final String message;

  const CircleError(this.message);

  @override
  List<Object> get props => [message];
}
