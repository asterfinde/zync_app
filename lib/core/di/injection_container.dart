// lib/core/di/injection_container.dart

import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

// Features - Circle
import '../../features/circle/data/datasources/circle_remote_data_source.dart';
import '../../features/circle/data/datasources/circle_remote_data_source_impl.dart';
import '../../features/circle/data/repositories/circle_repository_impl.dart';
import '../../features/circle/domain/repositories/circle_repository.dart';
import '../../features/circle/domain/usecases/create_circle.dart';
import '../../features/circle/domain/usecases/get_circle_stream_for_user.dart';
import '../../features/circle/domain/usecases/join_circle.dart';
import '../../features/circle/domain/usecases/update_circle_status.dart';

// Core
import '../network/network_info.dart';
import '../network/network_info_impl.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Features - Auth
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => SignInOrRegister(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );

  // Features - Circle
  sl.registerLazySingleton(() => CreateCircle(sl()));
  sl.registerLazySingleton(() => JoinCircle(sl()));
  sl.registerLazySingleton(() => GetCircleStreamForUser(sl()));
  sl.registerLazySingleton(() => UpdateCircleStatus(sl()));

  sl.registerLazySingleton<CircleRepository>(
    () => CircleRepositoryImpl(
      remoteDataSource: sl(),
      firebaseAuth: sl(),
      firestore: sl(),
    ),
  );

  sl.registerLazySingleton<CircleRemoteDataSource>(
    // CORRECCIÓN: El constructor de CircleRemoteDataSourceImpl espera la instancia de firestore.
    () => CircleRemoteDataSourceImpl(sl()),
  );

  // Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => Connectivity());
}

  // // lib/core/di/injection_container.dart

  // import 'package:get_it/get_it.dart';
  // import 'package:firebase_auth/firebase_auth.dart';
  // import 'package:cloud_firestore/cloud_firestore.dart';
  // import 'package:shared_preferences/shared_preferences.dart';
  // import 'package:connectivity_plus/connectivity_plus.dart';

  // // Features - Auth
  // import '../../features/auth/data/datasources/auth_local_data_source.dart';
  // import '../../features/auth/data/datasources/auth_local_data_source_impl.dart';
  // import '../../features/auth/data/datasources/auth_remote_data_source.dart';
  // import '../../features/auth/data/datasources/auth_remote_data_source_impl.dart';
  // import '../../features/auth/data/repositories/auth_repository_impl.dart';
  // import '../../features/auth/domain/repositories/auth_repository.dart';
  // import '../../features/auth/domain/usecases/get_current_user.dart';
  // import '../../features/auth/domain/usecases/sign_in_or_register.dart';
  // import '../../features/auth/domain/usecases/sign_out.dart';

  // // Features - Circle
  // import '../../features/circle/data/datasources/circle_remote_data_source.dart';
  // import '../../features/circle/data/datasources/circle_remote_data_source_impl.dart';
  // import '../../features/circle/data/repositories/circle_repository_impl.dart';
  // import '../../features/circle/domain/repositories/circle_repository.dart';
  // import '../../features/circle/domain/usecases/create_circle.dart';
  // import '../../features/circle/domain/usecases/get_circle_stream_for_user.dart';
  // import '../../features/circle/domain/usecases/join_circle.dart';
  // import '../../features/circle/domain/usecases/update_circle_status.dart';

  // // Core
  // import '../network/network_info.dart';
  // import '../network/network_info_impl.dart';

  // // Service Locator instance
  // final sl = GetIt.instance;

  // Future<void> init() async {
  //   // Features - Auth
  //   // Use cases
  //   sl.registerLazySingleton(() => GetCurrentUser(sl()));
  //   sl.registerLazySingleton(() => SignInOrRegister(sl()));
  //   sl.registerLazySingleton(() => SignOut(sl()));

  //   // Repository
  //   sl.registerLazySingleton<AuthRepository>(
  //     () => AuthRepositoryImpl(
  //       remoteDataSource: sl(),
  //       localDataSource: sl(),
  //       networkInfo: sl(),
  //     ),
  //   );

  //   // Data sources
  //   sl.registerLazySingleton<AuthRemoteDataSource>(
  //     () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()),
  //   );
  //   sl.registerLazySingleton<AuthLocalDataSource>(
  //     () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  //   );

  //   // Features - Circle
  //   // Use cases
  //   sl.registerLazySingleton(() => CreateCircle(sl()));
  //   sl.registerLazySingleton(() => JoinCircle(sl()));
  //   sl.registerLazySingleton(() => GetCircleStreamForUser(sl()));
  //   sl.registerLazySingleton(() => UpdateCircleStatus(sl()));

  //   // Repository
  //   sl.registerLazySingleton<CircleRepository>(
  //     () => CircleRepositoryImpl(
  //       remoteDataSource: sl(),
  //       firebaseAuth: sl(),
  //       firestore: sl(),
  //     ),
  //   );

  //   // Data sources
  //   sl.registerLazySingleton<CircleRemoteDataSource>(
  //     // --- CORRECCIÓN FINAL ---
  //     // El constructor de CircleRemoteDataSourceImpl espera un parámetro posicional, no uno nombrado.
  //     // Le pasamos `sl()` directamente, que GetIt sabe que debe resolver a la instancia de FirebaseFirestore.
  //     () => CircleRemoteDataSourceImpl(sl()),
  //   );

  //   // Core
  //   sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  //   // External
  //   final sharedPreferences = await SharedPreferences.getInstance();
  //   sl.registerLazySingleton(() => sharedPreferences);
  //   sl.registerLazySingleton(() => FirebaseAuth.instance);
  //   sl.registerLazySingleton(() => FirebaseFirestore.instance);
  //   sl.registerLazySingleton(() => Connectivity());
  // }
