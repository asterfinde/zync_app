import 'package:get_it/get_it.dart';
import 'package:nunakin_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:nunakin_app/features/auth/data/datasources/auth_local_data_source_impl.dart';
import 'package:nunakin_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:nunakin_app/features/auth/data/datasources/auth_remote_data_source_impl.dart';
import 'package:nunakin_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:nunakin_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:nunakin_app/features/auth/domain/usecases/get_current_user.dart';
import 'package:nunakin_app/features/auth/domain/usecases/sign_in_or_register.dart';
import 'package:nunakin_app/features/auth/domain/usecases/sign_out.dart';

Future<void> registerIdentityModule(GetIt sl) async {
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
}
