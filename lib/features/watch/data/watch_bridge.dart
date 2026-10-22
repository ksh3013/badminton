import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum WatchCommand { start, pause, resume, stop, marker }

enum WatchConnectionState { unavailable, disconnected, connected }

class WatchBridge extends ChangeNotifier {
  WatchBridge() {
    _channel.setMethodCallHandler(_handleCall);
  }

  static const _channel = MethodChannel('rally/watch');
  final _commands = StreamController<WatchCommand>.broadcast();
  final _connection = StreamController<WatchConnectionState>.broadcast();
  WatchConnectionState _connectionState = WatchConnectionState.unavailable;

  Stream<WatchCommand> get commands => _commands.stream;
  Stream<WatchConnectionState> get connectionChanges => _connection.stream;
  WatchConnectionState get connectionState => _connectionState;

  Future<void> refreshConnection() async {
    try {
      final response = await _channel.invokeMethod<Object?>('status');
      final connected = response is Map && response['connected'] == true;
      _setConnection(
        connected
            ? WatchConnectionState.connected
            : WatchConnectionState.disconnected,
      );
    } on MissingPluginException {
      _setConnection(WatchConnectionState.unavailable);
    } on PlatformException {
      _setConnection(WatchConnectionState.disconnected);
    }
  }

  Future<void> sendState({
    required String status,
    required Duration elapsed,
    required int uploadProgress,
  }) async {
    try {
      final response = await _channel.invokeMethod<Object?>('state', {
        'status': status,
        'elapsedSeconds': elapsed.inSeconds,
        'uploadProgress': uploadProgress,
      });
      if (response is Map && response['connected'] is bool) {
        _setConnection(
          response['connected'] == true
              ? WatchConnectionState.connected
              : WatchConnectionState.disconnected,
        );
      } else {
        // A successfully handled method call without a payload is treated as
        // connected by native implementations that cannot expose a status.
        _setConnection(WatchConnectionState.connected);
      }
    } on MissingPluginException {
      _setConnection(WatchConnectionState.unavailable);
    } on PlatformException {
      _setConnection(WatchConnectionState.disconnected);
    }
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'command') return;
    final value = call.arguments is Map
        ? call.arguments['value']
        : call.arguments;
    WatchCommand? command;
    for (final item in WatchCommand.values) {
      if (item.name == value) command = item;
    }
    if (command != null) {
      _setConnection(WatchConnectionState.connected);
      _commands.add(command);
    }
  }

  void _setConnection(WatchConnectionState next) {
    if (_connectionState == next) return;
    _connectionState = next;
    notifyListeners();
    if (!_connection.isClosed) _connection.add(next);
  }

  @override
  void dispose() {
    unawaited(_commands.close());
    unawaited(_connection.close());
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
