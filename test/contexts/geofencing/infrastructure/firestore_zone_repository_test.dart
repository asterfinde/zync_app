import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/geofencing/infrastructure/firestore_zone_repository.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreZoneRepository repo;

  const circleId = 'circle1';

  Zone sampleZone({
    String id = '',
    String name = 'Casa',
    ZoneType type = ZoneType.home,
    DateTime? createdAt,
  }) =>
      Zone(
        id: id,
        name: name,
        latitude: -12.0,
        longitude: -77.0,
        radiusMeters: 100,
        circleId: circleId,
        createdBy: 'user1',
        createdAt: createdAt ?? DateTime(2026, 1, 1),
        type: type,
        isPredefined: type.isPredefinedType,
      );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreZoneRepository(firestore);
  });

  group('createZone', () {
    test('genera id cuando Zone.id está vacío y persiste el documento', () async {
      final result = await repo.createZone(sampleZone());

      expect(result.isSuccess, isTrue);
      final created = result.valueOrNull!;
      expect(created.id, isNotEmpty);

      final doc = await firestore
          .collection('circles')
          .doc(circleId)
          .collection('zones')
          .doc(created.id)
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], 'Casa');
    });

    test('respeta el id provisto cuando Zone.id no está vacío', () async {
      final result = await repo.createZone(sampleZone(id: 'fixedId'));
      expect(result.valueOrNull!.id, 'fixedId');
    });
  });

  group('getCircleZones', () {
    test('retorna las zonas ordenadas por createdAt ascendente', () async {
      await repo.createZone(sampleZone(name: 'B', createdAt: DateTime(2026, 1, 2)));
      await repo.createZone(sampleZone(name: 'A', createdAt: DateTime(2026, 1, 1)));

      final result = await repo.getCircleZones(circleId);

      expect(result.isSuccess, isTrue);
      final zones = result.valueOrNull!;
      expect(zones.map((z) => z.name).toList(), ['A', 'B']);
    });

    test('círculo sin zonas → lista vacía', () async {
      final result = await repo.getCircleZones('empty');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('getZone', () {
    test('zona existente → Zone', () async {
      final created = (await repo.createZone(sampleZone())).valueOrNull!;
      final result = await repo.getZone(circleId, created.id);
      expect(result.valueOrNull?.name, 'Casa');
    });

    test('zona inexistente → null (Success)', () async {
      final result = await repo.getZone(circleId, 'nope');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });
  });

  group('updateZone', () {
    test('persiste los campos modificados', () async {
      final created = (await repo.createZone(sampleZone())).valueOrNull!;
      final updated = created.copyWith(name: 'Casa Nueva', radiusMeters: 200);

      final result = await repo.updateZone(updated);

      expect(result.isSuccess, isTrue);
      final fetched = (await repo.getZone(circleId, created.id)).valueOrNull!;
      expect(fetched.name, 'Casa Nueva');
      expect(fetched.radiusMeters, 200);
    });
  });

  group('deleteZone', () {
    test('elimina la zona', () async {
      final created = (await repo.createZone(sampleZone())).valueOrNull!;

      final result = await repo.deleteZone(circleId, created.id);

      expect(result.isSuccess, isTrue);
      expect((await repo.getZone(circleId, created.id)).valueOrNull, isNull);
    });
  });

  group('watchCircleZones', () {
    test('emite las zonas actuales del círculo', () async {
      await repo.createZone(sampleZone());
      final zones = await repo.watchCircleZones(circleId).first;
      expect(zones.length, 1);
      expect(zones.first.name, 'Casa');
    });
  });
}
