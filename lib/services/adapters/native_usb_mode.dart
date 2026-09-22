import 'package:flutter/services.dart';

import '../usb_mode.dart';

/// Android implementation of [UsbModePort].
///
/// Communicates with [UsbModeController] via MethodChannel "zee/usb_mode":
///   getUsbMode   → String  ("0", "1", or "")
///   setUsbMode   → Map {ok, reason?}
///   isWritable   → Boolean
///
/// ── T3-only write (platform signing required) ─────────────────────────────
///
/// persist.usb.mode is a system property protected by Linux DAC + SELinux.
/// Writing it requires android.uid.system (platform key + sharedUserId).
/// On the emulator / non-system build the native handler catches SecurityException
/// and returns {ok:false, reason:"requires-platform-signing"} — never crashes.
///
/// getUsbMode (reading) is unrestricted — works on any tier.
class NativeUsbMode implements UsbModePort {
  static const _channel = MethodChannel('zee/usb_mode');

  // Default until [refresh] / successful [setUsbMode] — never trust as truth.
  UsbMode _currentMode = UsbMode.peripheral;
  bool _writable = true; // optimistic until first write attempt

  @override
  UsbMode get currentMode => _currentMode;

  @override
  bool get writable => _writable;

  @override
  Future<String> getRawUsbMode() async {
    try {
      final raw = await _channel.invokeMethod<String>('getUsbMode');
      return raw ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<UsbMode> refresh({bool autoPreferred = false}) async {
    final raw = await getRawUsbMode();
    _currentMode = usbModeFromRaw(raw, autoPreferred: autoPreferred);
    return _currentMode;
  }

  @override
  Future<UsbModeResult> setUsbMode(UsbMode mode) async {
    // Auto writes "0" at the native level; the auto flag is stored in ConfigStore
    // by the caller (DiagnosticsScreen / ext.zee.setUsbMode).
    final nativeValue = switch (mode) {
      UsbMode.peripheral => '0',
      UsbMode.host => '1',
      UsbMode.auto => '0', // auto forces peripheral, boot re-applies
    };
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'setUsbMode',
        {'value': nativeValue},
      );
      final result = _parseResult(raw);
      if (result.ok) {
        _currentMode = mode;
      } else if (result.reason == 'requires-platform-signing') {
        // Lock writable=false so the UI disables the controls after first attempt.
        _writable = false;
      }
      return result;
    } catch (e) {
      _writable = false;
      return UsbModeResult(ok: false, reason: 'exception: $e');
    }
  }

  static UsbModeResult _parseResult(Map<String, Object?>? raw) {
    if (raw == null)
      return const UsbModeResult(ok: false, reason: 'null-response');
    final ok = raw['ok'] as bool? ?? false;
    final reason = raw['reason'] as String?;
    return UsbModeResult(ok: ok, reason: reason);
  }
}
