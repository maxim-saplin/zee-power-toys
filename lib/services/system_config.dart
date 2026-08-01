import 'dart:ui' show Locale;

/// Structured result from a system/cluster language write.
///
/// On T1 the FakeSystemConfig always returns [ok: true].
/// On T2 (emulator) the NativeSystemConfig returns [ok: false, reason: "unsupported-on-device"]
/// because the privileged AdaptAPI / Zeekr-OTA path is only available on the car (T3).
class LanguageSetResult {
  const LanguageSetResult({required this.ok, this.reason});

  /// True when the write succeeded (Fake in-memory, or on-car T3).
  final bool ok;

  /// Machine-readable reason for failure — "unsupported-on-device" when the
  /// privileged API is absent (emulator / stock Android); "exception" on
  /// unexpected errors. Null when [ok] is true.
  final String? reason;

  @override
  String toString() => ok ? 'ok' : 'error($reason)';
}

/// System locale and language configuration port.
///
/// Three concerns, clearly separated:
///   1. [systemLocale]     — read the current platform locale (available on T2 emulator).
///   2. [setSystemLanguage] — write the Android system locale (T3 privileged; guarded).
///   3. [setClusterLanguage]— write the instrument-cluster HMI language via AdaptAPI
///                            (SETTING_FUNC_LOCAL_CHANGED 0x20318a00, or IOtaSession.
///                            setSystemHMILanguage; T3 only; guarded).
///   4. [clusterSupported] — whether cluster write APIs are available on this device.
///
/// On T1 (desktop/test) → FakeSystemConfig; ok results, in-memory state.
/// On T2 (emulator)     → NativeSystemConfig; ok:false / unsupported-on-device.
/// On T3 (Zeekr car)    → NativeSystemConfig; real writes via AdaptAPI + Zeekr OTA.
abstract class SystemConfig {
  /// Current system locale as reported by the platform.
  /// On Android reads [java.util.Locale.getDefault()]; on desktop falls back to
  /// the LANG environment variable / the OS locale.
  Locale get systemLocale;

  /// Attempt to set the car's system HMI language via the AdaptAPI/OTA path
  /// (`IOtaSession.setSystemHMILanguage`, with an `AdaptInternalManager`
  /// fallback) — the same mechanism [setClusterLanguage] uses, since the OTA
  /// call's own name says *System*, not just cluster.
  ///
  /// Requires the ecarx AdaptAPI (absent on T1/T2) → [ok: false, reason:
  /// "unsupported-on-device"]. Present but denied at the privileged call →
  /// [ok: false, reason: "no-privilege"]. Whether this actually changes the
  /// car's system language can only be confirmed on T3 (see
  /// docs/issues/BACKLOG.md) — it may still fail there without platform
  /// signing.
  Future<LanguageSetResult> setSystemLanguage(Locale locale);

  /// Attempt to set the instrument-cluster HMI language.
  ///
  /// Mechanism (from phase0 ClusterLocaleProbe):
  ///   Path 1 — ICarFunction.setFunctionValue(0x20318a00, value)
  ///             SETTING_FUNC_LOCAL_CHANGED: 0 = Chinese, 1 = non-Chinese
  ///   Path 3 — IOtaSession.setSystemHMILanguage(langEnum)
  ///             37-language enum (30 = Russian, 11 = English US)
  /// Both paths require the ecarx AdaptAPI which is absent on the emulator and on
  /// stock Android devices → returns [ok: false, reason: "unsupported-on-device"].
  Future<LanguageSetResult> setClusterLanguage(Locale locale);

  /// Whether the cluster language write APIs are available on this device.
  ///
  /// Returns false on the emulator (no AdaptAPI), true on the Zeekr car.
  /// Used by the UI to disable the cluster picker off-car.
  Future<bool> clusterSupported();

  /// Whether the system language write APIs are available on this device.
  ///
  /// This is a **capability** probe (is the ecarx AdaptAPI present), not a
  /// **permission** probe — a prior version of this port gated the System
  /// picker on `CHANGE_CONFIGURATION`, a permission that can never be granted
  /// to this app, so the picker always reported unavailable for the wrong
  /// reason. Returns false on the emulator (no AdaptAPI), true on the Zeekr
  /// car. Used by the UI to disable the System picker off-car.
  Future<bool> systemSupported();
}
