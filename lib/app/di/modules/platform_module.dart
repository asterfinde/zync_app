import 'package:get_it/get_it.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';
import 'package:nunakin_app/platform/persistence/shared_prefs_kv_store.dart';

/// Platform infrastructure: persistencia local y (Sem 2) DomainEventBus.
Future<void> registerPlatformModule(GetIt sl) async {
  sl.registerLazySingleton<KvStore>(() => SharedPrefsKvStore(sl()));
  // TODO Sem 2: DomainEventBus
}
