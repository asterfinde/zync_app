// lib/features/auth/data/datasources/auth_local_data_source.dart

import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel userToCache);
  Future<UserModel?> getLastUser();
}