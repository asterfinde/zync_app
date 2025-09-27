// lib/features/auth/domain/repositories/auth_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart'; // Suponiendo que la entidad User ya está definida

/// AuthRepository es un contrato abstracto que define los métodos para la autenticación.
/// La capa de datos (Data) será responsable de implementar este contrato.
/// Usamos el paquete 'dartz' para manejar los resultados, devolviendo un Failure a la izquierda
/// o el resultado exitoso (el tipo genérico) a la derecha.
abstract class AuthRepository {
  /// Inicia sesión o registra a un usuario con su email y contraseña.
  ///
  /// Devuelve un [User] si la operación es exitosa.
  /// Devuelve un [Failure] si ocurre un error (ej. credenciales incorrectas, sin conexión).
  Future<Either<Failure, User>> signInOrRegister({
    required String email,
    required String password,
    String nickname,
  });

  /// Cierra la sesión del usuario actual.
  ///
  /// Devuelve `void` (a través de Right(null)) si la operación es exitosa.
  /// Devuelve un [Failure] si ocurre un error.
  Future<Either<Failure, void>> signOut();

  /// Obtiene el usuario actualmente autenticado.
  ///
  /// Devuelve el [User] actual si hay una sesión activa.
  /// Devuelve un [Failure] si no hay ningún usuario autenticado o si ocurre un error.
  Future<Either<Failure, User?>> getCurrentUser();
}
