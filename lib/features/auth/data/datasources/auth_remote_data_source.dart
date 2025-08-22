// lib/features/auth/data/datasources/auth_remote_data_source.dart

import '../models/user_model.dart';

/// Contrato para la fuente de datos remota.
/// Define los métodos que interactuarán con el backend (Firebase, API REST, etc.).
/// Lanzará una [ServerException] en caso de errores.
abstract class AuthRemoteDataSource {
  /// Inicia sesión o registra a un usuario con email y contraseña.
  /// Devuelve el [UserModel] si la autenticación es exitosa.
  Future<UserModel> signInOrRegister({
    required String email,
    required String password,
  });

  /// Cierra la sesión del usuario actual.
  Future<void> signOut();

  /// Obtiene el usuario actualmente autenticado.
  /// Devuelve [UserModel] si hay un usuario, de lo contrario null.
  Future<UserModel?> getCurrentUser();
}


// -----------------------------------------------------------------


// features/auth/data/datasources/auth_local_data_source.dart

import '../models/user_model.dart';

/// Contrato para la fuente de datos local.
/// Define los métodos para guardar y recuperar datos del usuario en caché.
/// Lanzará una [CacheException] en caso de errores.
abstract class AuthLocalDataSource {
  /// Guarda el [UserModel] en la caché local (ej. SharedPreferences).
  Future<void> cacheUser(UserModel userToCache);

  /// Obtiene el último [UserModel] guardado en la caché.
  Future<UserModel?> getLastUser();
}
