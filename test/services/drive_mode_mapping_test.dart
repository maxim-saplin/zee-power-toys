import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/drive_mode_mapping.dart';

void main() {
  group('DriveModeMapping', () {
    test('Adapt 0x22010100+n → eco/comfort/sport/other', () {
      const base = DriveModeMapping.kAdaptDriveModeId;
      expect(DriveModeMapping.fromAdaptRaw(base + 1), DriveMode.eco);
      expect(DriveModeMapping.fromAdaptRaw(base + 2), DriveMode.comfort);
      expect(DriveModeMapping.fromAdaptRaw(base + 3), DriveMode.sport);
      expect(DriveModeMapping.fromAdaptRaw(base + 4), DriveMode.other);
      expect(DriveModeMapping.fromAdaptRaw(base + 12), DriveMode.other);
    });

    test('sentinels → unknown; small ordinals accepted', () {
      expect(DriveModeMapping.fromAdaptRaw(255), DriveMode.unknown);
      expect(DriveModeMapping.fromAdaptRaw(-1), DriveMode.unknown);
      expect(DriveModeMapping.fromAdaptRaw(null), DriveMode.unknown);
      expect(DriveModeMapping.fromAdaptRaw(1), DriveMode.eco);
      expect(DriveModeMapping.fromAdaptRaw(2), DriveMode.comfort);
      expect(DriveModeMapping.fromAdaptRaw(3), DriveMode.sport);
    });

    test('hud labels', () {
      expect(DriveModeMapping.hudLabel(DriveMode.eco), 'ECO');
      expect(DriveModeMapping.hudLabel(DriveMode.comfort), 'Comfort');
      expect(DriveModeMapping.hudLabel(DriveMode.sport), 'Sport');
      expect(DriveModeMapping.hudLabel(DriveMode.other), 'Mode');
      expect(DriveModeMapping.hudLabel(DriveMode.unknown), '');
    });
  });
}
