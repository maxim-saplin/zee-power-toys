import 'car_signals.dart';

/// Honest Adapt `0x22010100` → [DriveMode] mapping (0104).
///
/// ECarX emits raw ints in the function-id family `0x22010100 + n`
/// (LynkCoTrack / AdaptAPI field notes), n = 1..14:
///   1 ECO, 2 COMFORT, 3 SPORT, 4 EV, 5 HYBRID, 6 POWER, 7 SNOW, 8 MUD,
///   9 ROCK, 10 SAND, 11 OFF-ROAD, 12 TRACK, 13 ADAPTIVE, 14 CUSTOM.
/// Sentinel 255 / −1 → [DriveMode.unknown]. Small ordinals 1..14 accepted
/// as a soft fallback if firmware ever emits offset-only.
class DriveModeMapping {
  DriveModeMapping._();

  static const int kAdaptDriveModeId = 0x22010100;

  static DriveMode fromAdaptRaw(int? raw) {
    if (raw == null || raw == 255 || raw == -1) return DriveMode.unknown;
    final offset = raw - kAdaptDriveModeId;
    final int? n;
    if (offset >= 1 && offset <= 64) {
      n = offset;
    } else if (raw >= 1 && raw <= 14) {
      n = raw;
    } else {
      return DriveMode.unknown;
    }
    return switch (n) {
      1 => DriveMode.eco,
      2 => DriveMode.comfort,
      3 => DriveMode.sport,
      _ => DriveMode.other,
    };
  }

  static DriveMode fromWireName(String? name) {
    if (name == null || name.isEmpty) return DriveMode.unknown;
    try {
      return DriveMode.values.byName(name);
    } catch (_) {
      return DriveMode.unknown;
    }
  }

  /// Short HUD / Simulate label (product Latin chips in EN + RU).
  static String hudLabel(DriveMode mode) => switch (mode) {
        DriveMode.eco => 'ECO',
        DriveMode.comfort => 'Comfort',
        DriveMode.sport => 'Sport',
        DriveMode.other => 'Mode',
        DriveMode.unknown => '',
      };
}
