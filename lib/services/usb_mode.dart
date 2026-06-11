/// USB mode port — exposes getUsbMode / setUsbMode to the Flutter layer.
///
/// Three states (matching zSupport's UI and persist.usb.mode values):
///   peripheral — "0": the DHU is a USB device; ADB from PC works.
///   host       — "1": the DHU is the USB host (connects other devices).
///   auto       — stored as a SharedPrefs flag; BootReceiver re-applies
///                peripheral on every boot (mirrors zSupport auto_usb_peripheral).
///
/// ── Tier behaviour ───────────────────────────────────────────────────────────
///   T1 (FakeUsbMode):    writable=true; in-memory state; default=peripheral.
///   T2 (NativeUsbMode):  reads the real property (likely "" on emulator);
///                        setUsbMode returns {ok:false, reason:"requires-platform-signing"}.
///   T3 (car, signed):    setUsbMode succeeds; persist.usb.mode changes.
library;

/// The three USB role states the DHU can be in.
///
/// Values map to persist.usb.mode: peripheral="0", host="1", auto=pref flag.
enum UsbMode {
  /// "0" — DHU is a USB peripheral (ADB target). Most useful for development.
  peripheral,

  /// "1" — DHU acts as a USB host. ADB from the DHU to an attached device.
  host,

  /// DHU applies peripheral on every BOOT_COMPLETED (stored in ConfigStore;
  /// re-applied by BootReceiver).  The raw property will read "0" after boot.
  auto,
}

/// Structured result from a [UsbModePort.setUsbMode] call.
class UsbModeResult {
  const UsbModeResult({required this.ok, this.reason});

  /// True when the write succeeded.
  final bool ok;

  /// Machine-readable failure reason:
  ///   "requires-platform-signing" — normal off-car result.
  ///   "exception: ..."            — unexpected native error.
  /// Null when [ok] is true.
  final String? reason;

  @override
  String toString() => ok ? 'ok' : 'error($reason)';
}

/// Port: USB mode read + write.
abstract class UsbModePort {
  /// Last known USB mode (default peripheral when unknown).
  UsbMode get currentMode;

  /// Whether the native setUsbMode write is expected to succeed on this device.
  /// True on T1 fake; optimistic on T2 (will fail at first write); true on T3.
  bool get writable;

  /// Read the raw persist.usb.mode value from the platform.
  /// Returns "0", "1", or "" (not set).  Available on all tiers.
  Future<String> getRawUsbMode();

  /// Attempt to set the USB mode.
  ///
  /// Maps:
  ///   UsbMode.peripheral → writes "0" (+ clears auto flag).
  ///   UsbMode.host       → writes "1" (+ clears auto flag).
  ///   UsbMode.auto       → writes "0" + persists auto_usb_peripheral flag.
  ///
  /// On T2/off-car returns {ok:false, reason:"requires-platform-signing"}.
  /// Never throws.
  Future<UsbModeResult> setUsbMode(UsbMode mode);
}
