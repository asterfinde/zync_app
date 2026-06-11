import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/infrastructure/firestore_presence_publisher.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestorePresencePublisher publisher;

  const circleId = 'circle1';
  const userId = 'user1';

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    publisher = FirestorePresencePublisher(firestore);
    // batch.update requiere que el documento del círculo ya exista.
    await firestore.collection('circles').doc(circleId).set({
      'members': [userId],
    });
  });

  test('Normal → memberStatus + statusEvents sin coordinates', () async {
    final result = await publisher.publish(
      state: const Normal(currentId: 'busy'),
      userId: userId,
      circleId: circleId,
    );

    expect(result.isSuccess, isTrue);

    final circle = await firestore.collection('circles').doc(circleId).get();
    final memberStatus =
        (circle.data()!['memberStatus'] as Map)[userId] as Map<String, dynamic>;
    expect(memberStatus['statusType'], 'busy');
    expect(memberStatus.containsKey('coordinates'), isFalse);

    final events = await firestore
        .collection('circles')
        .doc(circleId)
        .collection('statusEvents')
        .get();
    expect(events.docs.length, 1);
    expect(events.docs.first.data().containsKey('coordinates'), isFalse);
  });

  test('SOSActive → coordinates presentes en memberStatus y statusEvents', () async {
    final result = await publisher.publish(
      state: const SOSActive(previousId: 'fine', latitude: -12.05, longitude: -77.04),
      userId: userId,
      circleId: circleId,
    );

    expect(result.isSuccess, isTrue);

    final circle = await firestore.collection('circles').doc(circleId).get();
    final memberStatus =
        (circle.data()!['memberStatus'] as Map)[userId] as Map<String, dynamic>;
    expect(memberStatus['coordinates'],
        {'latitude': -12.05, 'longitude': -77.04});

    final events = await firestore
        .collection('circles')
        .doc(circleId)
        .collection('statusEvents')
        .get();
    expect(events.docs.first.data()['coordinates'],
        {'latitude': -12.05, 'longitude': -77.04});
  });
}
