import '../usb_mode.dart';

/// T1 fake for [UsbModePort].
///
/// Two modes, controlled by [unsupported]:
///   false (default) — writes succeed; in-memory state updated; writable=true.
///   true            — writes return {ok:false, reason:"requires-platform-signing"};
///                     writable=false (mirrors what the real device returns off-car).
///
/// [initialMode] sets the starting mode (default peripheral).
class FakeUsbMode implements UsbModePort {
  FakeUsbMode({
    UsbMode initialMode = UsbMode.peripheral,
    bool unsupported = false,
  })  : _currentMode = initialMode,
        _unsupported = unsupported; // ignore: prefer_initializing_formals

  final bool _unsupported;
  UsbMode _currentMode;

  /// The last mode passed to [setUsbMode] — null until first call.
  UsbMode? lastSetMode;

  @override
  UsbMode get currentMode => _currentMode;

  @override
  bool get writable => !_unsupported;

  @override
  Future<String> getRawUsbMode() async {
    return switch (_currentMode) {
      UsbMode.peripheral => '0',
      UsbMode.host => '1',
      UsbMode.auto => '0', // auto shows peripheral in the raw property
    };
  }

  @override
  Future<UsbModeResult> setUsbMode(UsbMode mode) async {
    if (_unsupported) {
      return const UsbModeResult(
        ok: false,
        reason: 'requires-platform-signing',
      );
    }
    lastSetMode = mode;
    _currentMode = mode;
    return const UsbModeResult(ok: true);
  }
}
