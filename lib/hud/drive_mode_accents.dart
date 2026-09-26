import 'package:flutter/material.dart';

import '../services/car_signals.dart';

/// 0112 unified drive-mode accents — toast **and** corner-dot share this
/// palette. Mode order in tip/docs/settings: **ECO → Comfort → Sport**.
///
/// | Mode | Color | Hex | Notes |
/// |------|-------|-----|-------|
/// | ECO | blue | `#3B82F6` | former Comfort blue (0109/0110) |
/// | Comfort / standard | green | `#3DDC84` | former ECO green (0109/0110) |
/// | Sport | red | `#FF3B30` | toast Sport red; drops 0110 yellow `#FFCC00` |
/// | other / unknown | soft grey (toast only) | `#C8CDD8` | corner-dot hides |
abstract final class DriveModeAccents {
  /// ECO — blue.
  static const Color eco = Color(0xFF3B82F6);

  /// Comfort / standard — green.
  static const Color comfort = Color(0xFF3DDC84);

  /// Sport — red (both toast and persistent corner-dot).
  static const Color sport = Color(0xFFFF3B30);

  /// other / unknown toast soft grey.
  static const Color other = Color(0xFFC8CDD8);

  /// Known-mode accent; null for other/unknown (corner-dot hide).
  static Color? known(DriveMode mode) => switch (mode) {
        DriveMode.eco => eco,
        DriveMode.comfort => comfort,
        DriveMode.sport => sport,
        DriveMode.other => null,
        DriveMode.unknown => null,
      };

  /// Toast accent including soft grey for other/unknown.
  static Color toast(DriveMode mode) => known(mode) ?? other;
}
