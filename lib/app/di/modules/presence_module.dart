import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/application/ports/presence_repository.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/enter_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/exit_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/raise_sos.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/set_manual_status.dart';
import 'package:nunakin_app/contexts/presence/infrastructure/firestore_presence_publisher.dart';
import 'package:nunakin_app/contexts/presence/infrastructure/shared_prefs_presence_repository.dart';
import 'package:nunakin_app/contexts/presence/presentation/view_models/presence_view_model.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';

Future<void> registerPresenceModule(GetIt sl) async {
  // Infrastructure
  sl.registerLazySingleton<PresenceRepository>(
    () => SharedPrefsPresenceRepository(sl<KvStore>()),
  );
  sl.registerLazySingleton<PresencePublisher>(
    () => FirestorePresencePublisher(sl<FirebaseFirestore>()),
  );

  // Use cases — Factory: nueva instancia por solicitud (stateless)
  sl.registerFactory(() => SetManualStatus(repository: sl(), publisher: sl()));
  sl.registerFactory(() => EnterSilentMode(repository: sl()));
  sl.registerFactory(() => ExitSilentMode(repository: sl()));
  sl.registerFactory(() => RaiseSOS(repository: sl(), publisher: sl()));

  // Presentation
  sl.registerLazySingleton(() => PresenceViewModel(repository: sl()));
}
