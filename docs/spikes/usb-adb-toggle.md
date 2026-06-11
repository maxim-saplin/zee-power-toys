---
spike: usb-adb-toggle
block: 0016
status: done
date: 2026-06-11
source: zSupport-1.3.5-release.apk decompile (x0/f.smali, D0/f.smali, TimeZoneSyncReceiver.smali)
---

# Spike: USB host/peripheral ADB toggle

## Mechanism

zSupport toggles the USB role by writing `persist.usb.mode` via `Runtime.exec(["/system/bin/setprop", "persist.usb.mode", value])`.  
The same value can be written without spawning a child process using `android.os.SystemProperties.set(key, value)` via reflection — our preferred path (safer in restricted SELinux contexts; no fork overhead).

| Value | Role | ADB behaviour |
|-------|------|---------------|
| `"0"` | **Peripheral** (ADB target) | DHU is visible to a connected PC as a USB device; `adb shell` works from the PC |
| `"1"` | **Host** | DHU acts as a USB host; ADB *from* the DHU to another device |
| `""`  | Unknown / not set | Behaviour is firmware-specific |

Auto mode (position 2 in zSupport's UI) stores `auto_usb_peripheral=true` in `SharedPreferences("app_prefs")` and the BOOT_COMPLETED receiver re-applies `"0"` on every boot.

## Signing requirement

`setprop persist.*` is protected by Linux DAC (UID-gated) **and** SELinux.  
Writing it requires the app to run as `android.uid.system` — achieved by:
- `android:sharedUserId="android.uid.system"` in `AndroidManifest.xml`, AND
- APK signed with the **platform key** (Zeekr build key).

Without platform signing the `setprop` child process exits non-zero and the reflection call throws `SecurityException`. Both are caught; the caller receives `{ok:false, reason:"requires-platform-signing"}`.

Reading (`getprop` / `SystemProperties.get`) is unrestricted — works on any device, any tier.

## Our implementation

### Native (Kotlin)
`android/.../usb/UsbModeController.kt` — MethodChannel `zee/usb_mode`:
- `getUsbMode()` → `SystemProperties.get("persist.usb.mode")` via reflection; returns the raw string (`"0"`, `"1"`, or `""`).
- `setUsbMode(value)` → reflect `SystemProperties.set(...)` first; fall back to `Runtime.exec(setprop)`; catch all security exceptions; return `{ok, reason?}`. On the emulator (not system-UID) always returns `{ok:false, reason:"requires-platform-signing"}`. **Never crashes.**
- `isWritable()` → best-effort: try a no-op read of the SystemProperties class; returns false when the property setter is blocked.

### Dart
`lib/services/usb_mode.dart` — `enum UsbMode { peripheral, host, auto }` + `UsbModeResult`.  
`lib/services/adapters/native_usb_mode.dart` — `NativeUsbMode` (calls the `zee/usb_mode` channel).  
`lib/services/fakes/fake_usb_mode.dart` — `FakeUsbMode` (T1: settable, writable=true by default).  
`lib/providers/usb_mode.dart` — `usbModeProvider` (injected like other service providers).

Auto mode: `setUsbMode(UsbMode.auto)` persists a `auto_usb_peripheral` flag in ConfigStore;
BootReceiver reads it on BOOT_COMPLETED and calls `setUsbMode("0")` via the native controller.

### UI
USB/ADB section added to `DiagnosticsScreen` — a `SegmentedButton<UsbMode>` (Peripheral / Host / Auto).  
When `writable=false` the button is disabled and a localized hint is shown:  
EN: "Requires platform signing — available on the car"  
RU: "Требуется системная подпись — доступно в автомобиле"

### Feedback Loop
`ext.zee.setUsbMode value=peripheral|host|auto` → mirrors the UI action via the fake.  
`ext.zee.readViewModel` now includes `{usbMode, usbWritable}`.

## Open questions

1. **Real value on stock DHU**: `adb shell getprop persist.usb.mode` on a live Zeekr 001.  
   The emulator returns `""` (property not set). Expected: `"0"` or `"1"`.
2. **SELinux policy**: even with `android.uid.system`, SELinux may block writes for our app domain on some firmware versions. Need `adb shell cat /sys/fs/selinux/policy` + `audit2allow` on real hardware.
3. **ADB enable separate**: zSupport does **not** touch `persist.service.adb.enable` — that is a separate Developer Options toggle. USB mode peripheral (`"0"`) is necessary but may not be sufficient.
4. **Boot-timing**: if the USB gadget driver only reads `persist.usb.mode` during its init (before `BOOT_COMPLETED`), our BootReceiver write may be too late. Verify on car.
5. **Reflection longevity**: `SystemProperties.set` is a hidden API; `--hidden-api-policy` may restrict it in future firmware. Exec fallback mitigates this.
