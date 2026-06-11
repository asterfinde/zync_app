import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/create_zone.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/delete_zone.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/update_zone.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/firestore_zone_repository.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const circleId = 'c1';
  const uid = 'u1';

  late FakeFirebaseFirestore firestore;
  late FirestoreZoneRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreZoneRepository(firestore);
  });

  MockFirebaseAuth auth({bool signedIn = true}) =>
      MockFirebaseAuth(signedIn: signedIn, mockUser: MockUser(uid: uid));

  Future<void> seedCircle({
    List<String> members = const [uid],
    Map<String, dynamic>? memberStatus,
  }) =>
      firestore.collection('circles').doc(circleId).set({
        'members': members,
        if (memberStatus != null) 'memberStatus': memberStatus,
      });

  Future<String> seedZone({required String name, ZoneType type = ZoneType.custom}) async {
    final z = Zone(
      id: '',
      name: name,
      latitude: -12,
      longitude: -77,
      radiusMeters: 100,
      circleId: circleId,
      createdBy: uid,
      createdAt: DateTime(2026, 1, 1),
      type: type,
      isPredefined: type.isPredefinedType,
    );
    return (await repo.createZone(z)).valueOrNull!.id;
  }

  group('CreateZone', () {
    test('éxito → persiste y devuelve la zona', () async {
      await seedCircle();
      final result = await CreateZone(repo, auth(), firestore).call(
        circleId: circleId,
        name: 'Gimnasio',
        latitude: -12,
        longitude: -77,
        radiusMeters: 100,
        type: ZoneType.custom,
      );
      expect(result.isSuccess, isTrue);
      expect((await repo.getCircleZones(circleId)).valueOrNull!.length, 1);
    });

    test('sin sesión → AuthFailure', () async {
      await seedCircle();
      final result = await CreateZone(repo, auth(signedIn: false), firestore).call(
        circleId: circleId, name: 'X', latitude: -12, longitude: -77,
        radiusMeters: 100, type: ZoneType.custom,
      );
      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('radio fuera de rango → ValidationFailure', () async {
      await seedCircle();
      final result = await CreateZone(repo, auth(), firestore).call(
        circleId: circleId, name: 'X', latitude: -12, longitude: -77,
        radiusMeters: 10, type: ZoneType.custom,
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('no miembro → DomainFailure', () async {
      await seedCircle(members: const ['otro']);
      final result = await CreateZone(repo, auth(), firestore).call(
        circleId: circleId, name: 'X', latitude: -12, longitude: -77,
        radiusMeters: 100, type: ZoneType.custom,
      );
      expect(result.failureOrNull, isA<DomainFailure>());
    });

    test('nombre duplicado → DomainFailure', () async {
      await seedCircle();
      await seedZone(name: 'Gimnasio');
      final result = await CreateZone(repo, auth(), firestore).call(
        circleId: circleId, name: 'gimnasio', latitude: -12, longitude: -77,
        radiusMeters: 100, type: ZoneType.custom,
      );
      expect(result.failureOrNull, isA<DomainFailure>());
    });
  });

  group('UpdateZone', () {
    test('éxito → preserva createdBy/createdAt y aplica cambios', () async {
      await seedCircle();
      final zoneId = await seedZone(name: 'Casa', type: ZoneType.home);

      final result = await UpdateZone(repo, auth(), firestore).call(
        circleId: circleId, zoneId: zoneId, name: 'Casa 2',
        latitude: -12, longitude: -77, radiusMeters: 200, type: ZoneType.home,
      );

      expect(result.isSuccess, isTrue);
      final updated = (await repo.getZone(circleId, zoneId)).valueOrNull!;
      expect(updated.name, 'Casa 2');
      expect(updated.radiusMeters, 200);
      expect(updated.createdBy, uid);
      expect(updated.createdAt, DateTime(2026, 1, 1));
    });

    test('zona inexistente → DomainFailure', () async {
      await seedCircle();
      final result = await UpdateZone(repo, auth(), firestore).call(
        circleId: circleId, zoneId: 'nope', name: 'X',
        latitude: -12, longitude: -77, radiusMeters: 100, type: ZoneType.custom,
      );
      expect(result.failureOrNull, isA<DomainFailure>());
    });

    test('nombre duplicado de otra zona → DomainFailure', () async {
      await seedCircle();
      await seedZone(name: 'Trabajo');
      final zoneId = await seedZone(name: 'Casa');
      final result = await UpdateZone(repo, auth(), firestore).call(
        circleId: circleId, zoneId: zoneId, name: 'Trabajo',
        latitude: -12, longitude: -77, radiusMeters: 100, type: ZoneType.custom,
      );
      expect(result.failureOrNull, isA<DomainFailure>());
    });
  });

  group('DeleteZone', () {
    test('éxito → elimina la zona', () async {
      await seedCircle();
      final zoneId = await seedZone(name: 'Casa');
      final result = await DeleteZone(repo, auth(), firestore).call(
        circleId: circleId, zoneId: zoneId,
      );
      expect(result.isSuccess, isTrue);
      expect((await repo.getZone(circleId, zoneId)).valueOrNull, isNull);
    });

    test('resetea memberStatus de miembros en la zona eliminada', () async {
      final zoneId = 'z-del';
      await seedCircle(memberStatus: {
        uid: {'statusType': 'studying', 'zoneId': zoneId, 'autoUpdated': true},
      });
      // Crear la zona con id fijo para que coincida con el memberStatus.
      await repo.createZone(Zone(
        id: zoneId, name: 'Colegio', latitude: -12, longitude: -77, radiusMeters: 100,
        circleId: circleId, createdBy: uid, createdAt: DateTime(2026, 1, 1),
        type: ZoneType.school, isPredefined: true,
      ));

      await DeleteZone(repo, auth(), firestore).call(circleId: circleId, zoneId: zoneId);

      final circle = await firestore.collection('circles').doc(circleId).get();
      final status = (circle.data()!['memberStatus'] as Map)[uid] as Map<String, dynamic>;
      expect(status['statusType'], 'fine');
      expect(status.containsKey('zoneId'), isFalse);
    });

    test('no miembro → DomainFailure', () async {
      await seedCircle(members: const ['otro']);
      final result = await DeleteZone(repo, auth(), firestore).call(
        circleId: circleId, zoneId: 'z1',
      );
      expect(result.failureOrNull, isA<DomainFailure>());
    });
  });
}
