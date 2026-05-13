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

    test('Unimplemented command throws UnimplementedError', () async {
      expect(
        () => bridge.invoke(const GetCurrentLocation()),
        throwsA(isA<UnimplementedError>()),
      );
      expect(calls, isEmpty);
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
