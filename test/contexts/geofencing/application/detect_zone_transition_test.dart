import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/detect_zone_transition.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/firestore_zone_event_repository.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/firestore_zone_repository.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone.dart';
import 'package:nunakin_app/shared/events/domain_event.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';

void main() {
  const circleId = 'circle1';
  const userId = 'user1';

  late FakeFirebaseFirestore firestore;
  late FirestoreZoneRepository zoneRepo;
  late MockFirebaseAuth auth;
  late FirestoreZoneEventRepository eventRepo;
  late DomainEventBus bus;

  Zone sampleZone({
    required String name,
    double lat = -12.0,
    double lng = -77.0,
    double radiusMeters = 100,
    ZoneType type = ZoneType.home,
  }) =>
      Zone(
        id: '',
        name: name,
        latitude: lat,
        longitude: lng,
        radiusMeters: radiusMeters,
        circleId: circleId,
        createdBy: userId,
        createdAt: DateTime(2026, 1, 1),
        type: type,
        isPredefined: type.isPredefinedType,
      );

  DetectZoneTransition buildDetect({Duration debounceDuration = Duration.zero}) =>
      DetectZoneTransition(
        zoneRepo: zoneRepo,
        eventRepo: eventRepo,
        auth: auth,
        bus: bus,
        debounceDuration: debounceDuration,
      );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    zoneRepo = FirestoreZoneRepository(firestore);
    auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: userId));
    eventRepo = FirestoreZoneEventRepository(firestore, auth);
    bus = DomainEventBus();
  });

  tearDown(() {
    bus.dispose();
  });

  test('entrada a zona → publica ZoneEntered, registra evento y actualiza currentZoneId', () async {
    final zone = (await zoneRepo.createZone(sampleZone(name: 'Casa'))).valueOrNull!;
    final detect = buildDetect();

    final events = <ZoneEntered>[];
    final sub = bus.on<ZoneEntered>().listen(events.add);

    await detect.onLocation(circleId: circleId, latitude: -12.0, longitude: -77.0);
    await pumpEventQueue();
    await sub.cancel();

    expect(events, hasLength(1));
    expect(events.first.zoneId, zone.id);
    expect(events.first.zoneTypeValue, 'home');
    expect(detect.currentZoneId, zone.id);

    final auditEvents = await eventRepo.listenToCircleEvents(circleId).first;
    expect(auditEvents, hasLength(1));
    expect(auditEvents.first.eventType.value, 'entry');
  });

  test('salida de zona → publica ZoneExited y limpia currentZoneId', () async {
    final zone = (await zoneRepo.createZone(sampleZone(name: 'Casa'))).valueOrNull!;
    final detect = buildDetect(); // debounce en 0 para permitir 2 transiciones seguidas

    await detect.onLocation(circleId: circleId, latitude: -12.0, longitude: -77.0);
    expect(detect.currentZoneId, zone.id);

    final exitEvents = <ZoneExited>[];
    final sub = bus.on<ZoneExited>().listen(exitEvents.add);

    // Ubicación lejos de la zona → detecta salida
    await detect.onLocation(circleId: circleId, latitude: -13.0, longitude: -78.0);
    await pumpEventQueue();
    await sub.cancel();

    expect(exitEvents, hasLength(1));
    expect(exitEvents.first.zoneId, zone.id);
    expect(detect.currentZoneId, isNull);
  });

  test('debounce: dos transiciones dentro de la ventana → la segunda se ignora', () async {
    final zone = (await zoneRepo.createZone(sampleZone(name: 'Casa'))).valueOrNull!;
    final detect = buildDetect(debounceDuration: const Duration(minutes: 2));

    await detect.onLocation(circleId: circleId, latitude: -12.0, longitude: -77.0);
    expect(detect.currentZoneId, zone.id);

    final exitEvents = <ZoneExited>[];
    final sub = bus.on<ZoneExited>().listen(exitEvents.add);

    // Intento de salida inmediato — debounce (2 min) activo, se ignora.
    await detect.onLocation(circleId: circleId, latitude: -13.0, longitude: -78.0);
    await pumpEventQueue();
    await sub.cancel();

    expect(exitEvents, isEmpty);
    expect(detect.currentZoneId, zone.id, reason: 'no debe cambiar mientras el debounce bloquea');
  });

  test('suppressNextCheck: omite la primera transición sin publicar ni auditar', () async {
    final zone = (await zoneRepo.createZone(sampleZone(name: 'Casa'))).valueOrNull!;
    final detect = buildDetect();
    detect.suppressNextCheck();

    final events = <ZoneEntered>[];
    final sub = bus.on<ZoneEntered>().listen(events.add);

    await detect.onLocation(circleId: circleId, latitude: -12.0, longitude: -77.0);
    await pumpEventQueue();
    await sub.cancel();

    expect(events, isEmpty, reason: 'la transición suprimida no debe publicar evento');
    expect(detect.currentZoneId, zone.id, reason: 'el estado interno sí se actualiza aunque se suprima el evento');

    final auditEvents = await eventRepo.listenToCircleEvents(circleId).first;
    expect(auditEvents, isEmpty);

    // La siguiente transición ya no está suprimida.
    final events2 = <ZoneExited>[];
    final sub2 = bus.on<ZoneExited>().listen(events2.add);
    await detect.onLocation(circleId: circleId, latitude: -13.0, longitude: -78.0);
    await pumpEventQueue();
    await sub2.cancel();
    expect(events2, hasLength(1));
  });

  test('zona eliminada mientras el usuario estaba adentro (Bug E) → no crashea, resetea sin publicar salida', () async {
    final zone = (await zoneRepo.createZone(sampleZone(name: 'Casa'))).valueOrNull!;
    // Zona sin relación, lejos, para que getCircleZones no quede vacío tras el
    // borrado — así la ejecución llega al guard específico de Bug E dentro de
    // _detectTransition en vez de cortar antes por "sin zonas configuradas".
    await zoneRepo.createZone(
      sampleZone(name: 'Otra', lat: 10.0, lng: 10.0, radiusMeters: 50),
    );
    final detect = buildDetect();

    await detect.onLocation(circleId: circleId, latitude: -12.0, longitude: -77.0);
    expect(detect.currentZoneId, zone.id);

    // Se borra la zona mientras el usuario está adentro.
    await zoneRepo.deleteZone(circleId, zone.id);

    final exitEvents = <ZoneExited>[];
    final sub = bus.on<ZoneExited>().listen(exitEvents.add);

    // Nueva ubicación fuera de cualquier zona restante.
    await detect.onLocation(circleId: circleId, latitude: -13.0, longitude: -78.0);
    await pumpEventQueue();
    await sub.cancel();

    expect(exitEvents, isEmpty, reason: 'no puede auditar salida de una zona que ya no existe');
    expect(detect.currentZoneId, isNull);
  });

  test('zonas solapadas → gana la de menor radio (más específica)', () async {
    final outer = (await zoneRepo.createZone(
      sampleZone(name: 'Zona amplia', radiusMeters: 500),
    ))
        .valueOrNull!;
    final inner = (await zoneRepo.createZone(
      sampleZone(name: 'Zona específica', radiusMeters: 50),
    ))
        .valueOrNull!;
    final detect = buildDetect();

    final events = <ZoneEntered>[];
    final sub = bus.on<ZoneEntered>().listen(events.add);

    // Ubicación dentro de ambos círculos (mismo centro que las zonas).
    await detect.onLocation(circleId: circleId, latitude: -12.0, longitude: -77.0);
    await pumpEventQueue();
    await sub.cancel();

    expect(events, hasLength(1));
    expect(events.first.zoneId, inner.id, reason: 'debe ganar la zona de menor radio');
    expect(events.first.zoneId, isNot(outer.id));
  });
}
