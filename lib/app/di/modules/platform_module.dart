import 'package:get_it/get_it.dart';
import 'package:nunakin_app/platform/bridge/android_native_bridge.dart';
import 'package:nunakin_app/platform/bridge/native_bridge.dart';
import 'package:nunakin_app/platform/persistence/kv_store.dart';
import 'package:nunakin_app/platform/persistence/shared_prefs_kv_store.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';

/// Platform infrastructure: persistencia local, DomainEventBus y NativeBridge.
Future<void> registerPlatformModule(GetIt sl) async {
  sl.registerLazySingleton<KvStore>(() => SharedPrefsKvStore(sl()));
  sl.registerLazySingleton<DomainEventBus>(DomainEventBus.new);
  sl.registerLazySingleton<NativeBridge>(AndroidNativeBridge.new);
}
