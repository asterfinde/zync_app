import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/geofence_status_writer.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/place_search_service.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_event_repository.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_repository.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/apply_geofence_status.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/create_zone.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/delete_zone.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/firestore_geofence_status_writer.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/firestore_zone_event_repository.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/firestore_zone_repository.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/places_sdk_search_service.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';

Future<void> registerGeofencingModule(GetIt sl) async {
  sl.registerLazySingleton<ZoneRepository>(
    () => FirestoreZoneRepository(sl<FirebaseFirestore>()),
  );

  sl.registerLazySingleton<ZoneEventRepository>(
    () => FirestoreZoneEventRepository(sl<FirebaseFirestore>(), sl<FirebaseAuth>()),
  );

  sl.registerLazySingleton<PlaceSearchService>(
    PlacesSdkSearchService.new,
  );

  sl.registerFactory(
    () => CreateZone(sl<ZoneRepository>(), sl<FirebaseAuth>(), sl<FirebaseFirestore>()),
  );
  sl.registerFactory(
    () => DeleteZone(sl<ZoneRepository>(), sl<FirebaseAuth>(), sl<FirebaseFirestore>()),
  );

  sl.registerLazySingleton<GeofenceStatusWriter>(
    () => FirestoreGeofenceStatusWriter(
      sl<FirebaseFirestore>(),
      sl<FirebaseAuth>(),
    ),
  );

  sl.registerSingleton<ApplyGeofenceStatus>(
    ApplyGeofenceStatus(
      bus:    sl<DomainEventBus>(),
      writer: sl<GeofenceStatusWriter>(),
    )..initialize(),
  );
}
