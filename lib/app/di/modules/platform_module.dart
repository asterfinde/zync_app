import 'package:get_it/get_it.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';
import 'package:nunakin_app/platform/persistence/shared_prefs_kv_store.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';

/// Platform infrastructure: persistencia local y DomainEventBus.
Future<void> registerPlatformModule(GetIt sl) async {
  sl.registerLazySingleton<KvStore>(() => SharedPrefsKvStore(sl()));
  sl.registerLazySingleton<DomainEventBus>(DomainEventBus.new);
}
