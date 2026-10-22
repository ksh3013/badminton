import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badmintonmatchrecord/features/watch/data/watch_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('rally/watch');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'maps native watch status and state delivery to connected state',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'status') return {'connected': false};
            if (call.method == 'state') return {'connected': true};
            return null;
          });
      final bridge = WatchBridge();
      addTearDown(bridge.dispose);

      await bridge.refreshConnection();
      expect(bridge.connectionState, WatchConnectionState.disconnected);

      await bridge.sendState(
        status: 'recording',
        elapsed: const Duration(seconds: 12),
        uploadProgress: 40,
      );
      expect(bridge.connectionState, WatchConnectionState.connected);
      expect(calls.map((call) => call.method), ['status', 'state']);
    },
  );

  test('marks the bridge unavailable when no native channel exists', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw MissingPluginException();
        });
    final bridge = WatchBridge();
    addTearDown(bridge.dispose);

    await bridge.refreshConnection();
    expect(bridge.connectionState, WatchConnectionState.unavailable);
  });

  test(
    'keeps a disconnected state when native state delivery reports false',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'state') return {'connected': false};
            return null;
          });
      final bridge = WatchBridge();
      addTearDown(bridge.dispose);

      await bridge.sendState(
        status: 'recording',
        elapsed: const Duration(seconds: 3),
        uploadProgress: 10,
      );

      expect(bridge.connectionState, WatchConnectionState.disconnected);
    },
  );
}
