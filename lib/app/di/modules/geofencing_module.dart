import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/geofence_status_writer.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/apply_geofence_status.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/firestore_geofence_status_writer.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';

Future<void> registerGeofencingModule(GetIt sl) async {
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
