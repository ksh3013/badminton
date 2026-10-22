import 'package:flutter/services.dart';

class DeviceReadiness {
  const DeviceReadiness({this.availableBytes, this.batteryPercent});

  final int? availableBytes;
  final int? batteryPercent;

  String? get warning {
    final warnings = <String>[];
    if (availableBytes != null && availableBytes! < 512 * 1024 * 1024) {
      warnings.add('저장공간이 512MB보다 적어요. 녹화 중 저장공간이 부족할 수 있어요.');
    }
    if (batteryPercent != null && batteryPercent! < 15) {
      warnings.add('배터리가 15% 미만이에요. 장시간 녹화가 중단될 수 있어요.');
    }
    return warnings.isEmpty ? null : warnings.join('\n');
  }
}

class DeviceReadinessService {
  static const _channel = MethodChannel('rally/device');

  Future<DeviceReadiness> read() async {
    try {
      final response = await _channel.invokeMethod<Object?>('health');
      if (response is! Map) return const DeviceReadiness();
      return DeviceReadiness(
        availableBytes: (response['availableBytes'] as num?)?.toInt(),
        batteryPercent: (response['batteryPercent'] as num?)?.toInt(),
      );
    } on MissingPluginException {
      return const DeviceReadiness();
    } on PlatformException {
      return const DeviceReadiness();
    }
  }
}
