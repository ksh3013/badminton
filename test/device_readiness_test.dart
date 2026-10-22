import 'package:flutter_test/flutter_test.dart';

import 'package:badmintonmatchrecord/features/recording/data/device_readiness_service.dart';

void main() {
  test('warns when storage or battery is below recording thresholds', () {
    const readiness = DeviceReadiness(
      availableBytes: 256 * 1024 * 1024,
      batteryPercent: 10,
    );

    expect(readiness.warning, contains('저장공간'));
    expect(readiness.warning, contains('배터리'));
  });

  test('does not warn when device health is sufficient', () {
    const readiness = DeviceReadiness(
      availableBytes: 2 * 1024 * 1024 * 1024,
      batteryPercent: 80,
    );

    expect(readiness.warning, isNull);
  });
}
