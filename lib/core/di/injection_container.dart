// lib/core/di/injection_container.dart

import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Features - Auth
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_local_data_source_impl.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source_impl.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/sign_in_or_register.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// Core
import '../network/network_info.dart';
import '../network/network_info_impl.dart';


// Service Locator instance
final sl = GetIt.instance;

Future<void> init() async {
  // Features - Auth
  // BLoC
  sl.registerFactory(
    () => AuthBloc(
      signInOrRegister: sl(),
      signOut: sl(),
      getCurrentUser: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => SignInOrRegister(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );

  // Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => Connectivity());
}
