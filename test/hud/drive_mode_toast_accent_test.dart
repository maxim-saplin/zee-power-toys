import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/drive_mode_accents.dart';
import 'package:zee_power_toys/hud/drive_mode_corner_dot.dart';
import 'package:zee_power_toys/hud/drive_mode_toast.dart';
import 'package:zee_power_toys/services/car_signals.dart';

void main() {
  test('0112 toast accents: ECO blue, Comfort green, Sport red', () {
    expect(driveModeToastAccent(DriveMode.eco), DriveModeAccents.eco);
    expect(driveModeToastAccent(DriveMode.comfort), DriveModeAccents.comfort);
    expect(driveModeToastAccent(DriveMode.sport), DriveModeAccents.sport);
    expect(driveModeToastAccent(DriveMode.other), DriveModeAccents.other);
    expect(driveModeToastAccent(DriveMode.unknown), DriveModeAccents.other);

    expect(driveModeToastAccent(DriveMode.eco), const Color(0xFF3B82F6));
    expect(driveModeToastAccent(DriveMode.comfort), const Color(0xFF3DDC84));
    expect(driveModeToastAccent(DriveMode.sport), const Color(0xFFFF3B30));

    // Drop 0109 ECO green / Comfort blue swap leftovers and 0104 cyan/orange.
    expect(driveModeToastAccent(DriveMode.eco), isNot(const Color(0xFF3DDC84)));
    expect(driveModeToastAccent(DriveMode.comfort), isNot(const Color(0xFF3B82F6)));
    expect(driveModeToastAccent(DriveMode.comfort), isNot(const Color(0xFF7EC8FF)));
    expect(driveModeToastAccent(DriveMode.sport), isNot(const Color(0xFFFF8A4C)));
  });

  test('0112 toast and corner-dot share ECO→Comfort→Sport palette', () {
    for (final mode in [DriveMode.eco, DriveMode.comfort, DriveMode.sport]) {
      expect(
        driveModeCornerDotColor(mode),
        driveModeToastAccent(mode),
        reason: mode.name,
      );
    }
    expect(driveModeCornerDotColor(DriveMode.sport), isNot(const Color(0xFFFFCC00)));
  });
}
