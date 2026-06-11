import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/usb_mode.dart';

/// Provider for [UsbModePort] — injected via ProviderScope.overrides at startup.
/// T1 → FakeUsbMode (default peripheral, writable=true).
/// T2 → NativeUsbMode (reads real property; writes return requires-platform-signing).
/// T3 → NativeUsbMode on platform-signed build (writes succeed).
final usbModeProvider = Provider<UsbModePort>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});
