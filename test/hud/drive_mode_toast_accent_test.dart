import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/drive_mode_toast.dart';
import 'package:zee_power_toys/services/car_signals.dart';

void main() {
  test('0109 toast accents: ECO green, Comfort blue, Sport red', () {
    expect(driveModeToastAccent(DriveMode.eco), const Color(0xFF3DDC84));
    expect(driveModeToastAccent(DriveMode.comfort), const Color(0xFF3B82F6));
    expect(driveModeToastAccent(DriveMode.sport), const Color(0xFFFF3B30));
    expect(driveModeToastAccent(DriveMode.other), const Color(0xFFC8CDD8));
    expect(driveModeToastAccent(DriveMode.unknown), const Color(0xFFC8CDD8));

    // Drop 0104 cyan / orange palette.
    expect(driveModeToastAccent(DriveMode.comfort), isNot(const Color(0xFF7EC8FF)));
    expect(driveModeToastAccent(DriveMode.sport), isNot(const Color(0xFFFF8A4C)));
  });
}
