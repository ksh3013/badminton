import 'package:flutter/services.dart';

class RecordingForegroundBridge {
  static const _channel = MethodChannel('rally/recording');

  Future<void> start() async {
    try {
      await _channel.invokeMethod<void>('startForeground');
    } on MissingPluginException {
      // Desktop, iOS and test runs do not expose the Android service.
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopForeground');
    } on MissingPluginException {
      // Desktop, iOS and test runs do not expose the Android service.
    }
  }
}
