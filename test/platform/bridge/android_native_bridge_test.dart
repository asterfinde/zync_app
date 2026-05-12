import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/platform/bridge/android_native_bridge.dart';
import 'package:nunakin_app/platform/bridge/native_command.dart';

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
}
