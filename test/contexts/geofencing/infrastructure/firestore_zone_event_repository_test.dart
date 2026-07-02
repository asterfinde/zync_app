import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/firestore_zone_event_repository.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone_event.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  const circleId = 'circle1';

  FirestoreZoneEventRepository repoWith(MockFirebaseAuth auth) =>
      FirestoreZoneEventRepository(firestore, auth);

  MockFirebaseAuth signedInAs(String uid) =>
      MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('createEvent', () {
    test('persiste el evento y devuelve la entidad con id y userId', () async {
      final repo = repoWith(signedInAs('user1'));

      final event = await repo.createEvent(
        circleId: circleId,
        zoneId: 'zoneA',
        eventType: ZoneEventType.entry,
        latitude: -12.0,
        longitude: -77.0,
        zoneName: 'Casa',
      );

      expect(event.id, isNotEmpty);
      expect(event.userId, 'user1');
      expect(event.eventType, ZoneEventType.entry);

      final doc = await firestore
          .collection('circles')
          .doc(circleId)
          .collection('zone_events')
          .doc(event.id)
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['zoneId'], 'zoneA');
      expect(doc.data()!['zoneName'], 'Casa');
    });

    test('omite zoneName en el documento cuando es null', () async {
      final repo = repoWith(signedInAs('user1'));

      final event = await repo.createEvent(
        circleId: circleId,
        zoneId: 'zoneA',
        eventType: ZoneEventType.exit,
        latitude: -12.0,
        longitude: -77.0,
      );

      final doc = await firestore
          .collection('circles')
          .doc(circleId)
          .collection('zone_events')
          .doc(event.id)
          .get();
      expect(doc.data()!.containsKey('zoneName'), isFalse);
    });

    test('lanza si el usuario no está autenticado', () async {
      final repo = repoWith(MockFirebaseAuth(signedIn: false));

      await expectLater(
        () => repo.createEvent(
          circleId: circleId,
          zoneId: 'zoneA',
          eventType: ZoneEventType.entry,
          latitude: -12.0,
          longitude: -77.0,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('listenToCircleEvents', () {
    test('emite los eventos del círculo, más recientes primero', () async {
      final repo = repoWith(signedInAs('user1'));

      await repo.createEvent(
        circleId: circleId,
        zoneId: 'zoneA',
        eventType: ZoneEventType.entry,
        latitude: -12.0,
        longitude: -77.0,
        zoneName: 'Casa',
      );
      // Separación explícita para garantizar timestamps distintos y orden estable.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.createEvent(
        circleId: circleId,
        zoneId: 'zoneB',
        eventType: ZoneEventType.exit,
        latitude: -12.1,
        longitude: -77.1,
        zoneName: 'Trabajo',
      );

      final events = await repo.listenToCircleEvents(circleId).first;

      expect(events.length, 2);
      // orderBy timestamp descending → el último creado va primero.
      expect(events.first.zoneId, 'zoneB');
      expect(events.last.zoneId, 'zoneA');
    });

    test('círculo sin eventos → lista vacía', () async {
      final repo = repoWith(signedInAs('user1'));
      final events = await repo.listenToCircleEvents('empty').first;
      expect(events, isEmpty);
    });
  });
}
