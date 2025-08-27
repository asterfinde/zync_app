// lib/features/auth/data/datasources/auth_local_data_source_impl.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';
import 'auth_local_data_source.dart';

// CORRECCIÓN: Constante en lowerCamelCase para seguir las guías de estilo.
const String kCachedUser = 'CACHED_USER';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> cacheUser(UserModel userToCache) {
    return sharedPreferences.setString(
      kCachedUser,
      json.encode(userToCache.toJson()),
    );
  }

  @override
  Future<UserModel?> getLastUser() {
    final jsonString = sharedPreferences.getString(kCachedUser);
    if (jsonString != null) {
      return Future.value(UserModel.fromJson(json.decode(jsonString)));
    } else {
      return Future.value(null);
    }
  }
}
