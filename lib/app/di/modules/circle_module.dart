import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/application/use_cases/approve_join_request.dart';
import 'package:nunakin_app/contexts/circle/application/use_cases/delete_account.dart';
import 'package:nunakin_app/contexts/circle/application/use_cases/join_circle.dart';
import 'package:nunakin_app/contexts/circle/infrastructure/firestore_circle_repository.dart';
import 'package:nunakin_app/contexts/circle/presentation/view_models/circle_view_model.dart';
import 'package:nunakin_app/services/circle_service.dart';

Future<void> registerCircleModule(GetIt sl) async {
  // Legacy — CircleService en GetIt para ser inyectable en FirestoreCircleRepository
  sl.registerLazySingleton(() => CircleService());

  // Infrastructure
  sl.registerLazySingleton<CircleRepository>(
    () => FirestoreCircleRepository(
      sl<CircleService>(),
      sl<FirebaseFirestore>(),
      sl<FirebaseAuth>(),
    ),
  );

  // Presentation
  sl.registerLazySingleton(
    () => CircleViewModel(repository: sl<CircleRepository>()),
  );

  // Use cases
  sl.registerLazySingleton(
    () => JoinCircle(repository: sl<CircleRepository>()),
  );
  sl.registerLazySingleton(
    () => ApproveJoinRequest(repository: sl<CircleRepository>()),
  );
  sl.registerLazySingleton(
    () => DeleteAccount(repository: sl<CircleRepository>()),
  );
}
