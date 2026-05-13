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
  });
}
