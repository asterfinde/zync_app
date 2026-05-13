import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/platform/bridge/android_native_bridge.dart';
import 'package:nunakin_app/platform/bridge/native_command.dart';
import 'package:nunakin_app/platform/bridge/native_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidNativeBridge.invoke', () {
    late MethodChannel channel;
    late List<MethodCall> calls;
    late AndroidNativeBridge bridge;

    setUp(() {
      channel = const MethodChannel(AndroidNativeBridge.channelName);
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getCurrentLocation') {
          return {'lat': 1.23, 'lng': 4.56};
        }
        return null;
      });
      bridge = AndroidNativeBridge(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('ActivateSilentMode invokes "activateSilentMode" on bridge channel',
        () async {
      await bridge.invoke(const ActivateSilentMode());
      expect(calls, hasLength(1));
      expect(calls.single.method, 'activateSilentMode');
      expect(calls.single.arguments, isNull);
    });

    test('DeactivateSilentMode invokes "deactivateSilentMode" on bridge channel',
        () async {
      await bridge.invoke(const DeactivateSilentMode());
      expect(calls, hasLength(1));
      expect(calls.single.method, 'deactivateSilentMode');
      expect(calls.single.arguments, isNull);
    });

    test('GetCurrentLocation invokes "getCurrentLocation" and parses result',
        () async {
      final loc = await bridge.invoke(const GetCurrentLocation());
      expect(calls, hasLength(1));
      expect(calls.single.method, 'getCurrentLocation');
      expect(loc.lat, closeTo(1.23, 0.001));
      expect(loc.lng, closeTo(4.56, 0.001));
    });

    test('SetUserSession invokes "setUserSession" with uid and email', () async {
      await bridge.invoke(const SetUserSession(uid: 'u1', email: 'e@e.com'));
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setUserSession');
      expect(calls.single.arguments['uid'], 'u1');
      expect(calls.single.arguments['email'], 'e@e.com');
    });

    test('ClearSession invokes "clearSession" with no arguments', () async {
      await bridge.invoke(const ClearSession());
      expect(calls, hasLength(1));
      expect(calls.single.method, 'clearSession');
      expect(calls.single.arguments, isNull);
    });

    // Día 5 — Test 11
    test('RegisterZone invokes "registerZone" with zoneId/lat/lng/radius', () async {
      await bridge.invoke(const RegisterZone(
        zoneId: 'z1',
        lat: 1.0,
        lng: 2.0,
        radiusMeters: 100.0,
      ));
      expect(calls, hasLength(1));
      expect(calls.single.method, 'registerZone');
      expect(calls.single.arguments['zoneId'], 'z1');
      expect(calls.single.arguments['lat'], 1.0);
      expect(calls.single.arguments['lng'], 2.0);
      expect(calls.single.arguments['radiusMeters'], 100.0);
    });

    // Día 5 — Test 12
    test('UnregisterZone invokes "unregisterZone" with zoneId', () async {
      await bridge.invoke(const UnregisterZone(zoneId: 'z1'));
      expect(calls, hasLength(1));
      expect(calls.single.method, 'unregisterZone');
      expect(calls.single.arguments, {'zoneId': 'z1'});
    });

    // Día 5 — Test 13
    test('SetBadgeCount invokes "setBadgeCount" with count', () async {
      await bridge.invoke(const SetBadgeCount(3));
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setBadgeCount');
      expect(calls.single.arguments, {'count': 3});
    });

    test('channelName is "nunakin/bridge"', () {
      expect(AndroidNativeBridge.channelName, 'nunakin/bridge');
    });
  });

  group('AndroidNativeBridge events (Kotlin→Dart)', () {
    late AndroidNativeBridge bridge;
    const codec = StandardMethodCodec();

    setUp(() {
      bridge = AndroidNativeBridge();
      bridge.initialize();
    });

    tearDown(() {
      bridge.dispose();
    });

    test('statusUpdated event emits StatusUpdatedFromNotification', () async {
      final expectation = expectLater(
        bridge.events,
        emits(isA<StatusUpdatedFromNotification>()
            .having((e) => e.statusId, 'statusId', 'fine')),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AndroidNativeBridge.channelName,
        codec.encodeMethodCall(
          const MethodCall('nativeEvent', {'type': 'statusUpdated', 'statusId': 'fine'}),
        ),
        (ByteData? _) {},
      );

      await expectation;
    });

    test('silentDeactivated event emits SilentDeactivatedByUser', () async {
      final expectation = expectLater(
        bridge.events,
        emits(isA<SilentDeactivatedByUser>()),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AndroidNativeBridge.channelName,
        codec.encodeMethodCall(
          const MethodCall('nativeEvent', {'type': 'silentDeactivated'}),
        ),
        (ByteData? _) {},
      );

      await expectation;
    });

    test('unknown event type does not emit anything', () async {
      final events = <NativeEvent>[];
      final sub = bridge.events.listen(events.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AndroidNativeBridge.channelName,
        codec.encodeMethodCall(
          const MethodCall('nativeEvent', {'type': 'unknown_xyz'}),
        ),
        (ByteData? _) {},
      );

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events, isEmpty);
    });

    // Día 5 — Test 14
    test('geofenceEntered event emits GeofenceEntered with zoneId', () async {
      final expectation = expectLater(
        bridge.events,
        emits(isA<GeofenceEntered>()
            .having((e) => e.zoneId, 'zoneId', 'z1')),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AndroidNativeBridge.channelName,
        codec.encodeMethodCall(
          const MethodCall('nativeEvent', {'type': 'geofenceEntered', 'zoneId': 'z1'}),
        ),
        (ByteData? _) {},
      );

      await expectation;
    });

    // Día 5 — Test 15
    test('geofenceExited event emits GeofenceExited with zoneId', () async {
      final expectation = expectLater(
        bridge.events,
        emits(isA<GeofenceExited>()
            .having((e) => e.zoneId, 'zoneId', 'z1')),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AndroidNativeBridge.channelName,
        codec.encodeMethodCall(
          const MethodCall('nativeEvent', {'type': 'geofenceExited', 'zoneId': 'z1'}),
        ),
        (ByteData? _) {},
      );

      await expectation;
    });
  });
}
