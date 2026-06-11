# Knowledge: zsupport-usb-adb-toggle

## zSupport 1.3.5 USB Host/Peripheral Toggle — Decompilation Findings

### Executive Summary

zSupport toggles USB mode by **shelling out to `/system/bin/setprop persist.usb.mode <value>`** as a child process. It reads current state with `/system/bin/getprop persist.usb.mode`. This is a raw system-property write, not a Settings.Global/Secure key, not a service call, and not a configfs/gadget write. The app can execute this because it is signed with the **platform key** (`PLATFORM.RSA` in META-INF) and declares `android:sharedUserId="android.uid.system"`.

---

### Mechanism in Detail

#### 1. Reading current USB mode — `x0/f.i()` (static)

File: `/tmp/zsupport_decomp/smali/x0/f.smali`, lines 825–1084  
Log tag: `AnyAppSwitchUSBHelper`

```smali
const-string v5, "/system/bin/getprop"
const-string v2, "persist.usb.mode"
filled-new-array {v5, v2}, [Ljava/lang/String;   ; args = ["/system/bin/getprop", "persist.usb.mode"]
invoke-virtual {v4, v2}, Ljava/lang/Runtime;->exec([Ljava/lang/String;)Ljava/lang/Process;
```

- Executes `Runtime.exec(new String[]{"/system/bin/getprop", "persist.usb.mode"})`
- Reads stdout via `BufferedReader.readLine()`
- Returns the string value, or "Unknown" on failure
- Log: "getUSBMode called", "Reading property persist.usb.mode", "Read property persist.usb.mode: <value>"

#### 2. Writing USB mode — `x0/f.o(String mode)` (static)

File: `/tmp/zsupport_decomp/smali/x0/f.smali`, lines 2180–2424  
Log tag: `AnyAppSwitchUSBHelper`

```smali
const-string v5, "/system/bin/setprop"
const-string v1, "persist.usb.mode"
filled-new-array {v5, v1, p0}, [Ljava/lang/String;   ; args = ["/system/bin/setprop", "persist.usb.mode", mode]
invoke-virtual {v0, v1}, Ljava/lang/Runtime;->exec([Ljava/lang/String;)Ljava/lang/Process;
invoke-virtual {v0}, Ljava/lang/Process;->waitFor()I
invoke-virtual {v0}, Ljava/lang/Process;->exitValue()I
```

- Executes `Runtime.exec(new String[]{"/system/bin/setprop", "persist.usb.mode", mode})`
- `mode` is either `"0"` (peripheral) or `"1"` (host)
- Waits for process completion, checks exit code (0 = success)
- On failure, reads stderr stream for logging
- Returns boolean success/failure

#### 3. Mode value encoding

File: `/tmp/zsupport_decomp/smali/x0/f.smali`, `e(String)` method (lines 433–491) — the "format USB mode" helper:

| Property value | Display label | Position index |
|---|---|---|
| `"0"` | "peripheral" | 0 |
| `"1"` | "host" | 1 |
| anything else | "unknown" | — |

#### 4. UI — SegmentedButtonGroup with 3 positions

File: `/tmp/zsupport_decomp/res/layout/activity_main.xml`, view id `@id/usbModeSwitcher`

Three buttons:
- Position 0 → **Peripheral** (drawable `baseline_usb_54`) → writes `"0"`
- Position 1 → **Host** (drawable `baseline_usb_off_54`) → writes `"1"`
- Position 2 → **AUTO** (drawable `baseline_autorenew_54`) → triggers "auto USB peripheral mode"

#### 5. Toggle flow (coroutine chain)

When user changes the segmented button (`SegmentedButtonGroup.setOnPositionChangedListener`):

1. `D0/f.a(int position)` — listener callback; maps position 0 or 2 → mode string `"0"`, position 1 → `"1"`. Skips if `z` (programmatic change guard) is set. Launches coroutine `D0/h`.
   - File: `/tmp/zsupport_decomp/smali/D0/f.smali`

2. `D0/h.g()` — "set USB mode" coroutine entry. Calls `x0/f.o(modeString)` on the IO dispatcher. Stores result in `LQ0/g` (success flag). Then switches to main thread and launches `D0/g`.
   - File: `/tmp/zsupport_decomp/smali/D0/h.smali`, line 209: `invoke-static {v7}, Lx0/f;->o(Ljava/lang/String;)Z`

3. `D0/g.g()` — UI result callback. On success: shows Toast "USB Mode set to <mode>", logs "USB Mode successfully set to <mode>". On failure: shows "Failed to set USB Mode" Toast, reverts segmented button to previous position.
   - File: `/tmp/zsupport_decomp/smali/D0/g.smali`, line 335: `const-string p1, "USB Mode successfully set to "`

#### 6. Startup read flow

On `onCreate`, coroutine `D0/k` is launched (Dispatchers.IO):

1. `D0/k.g()` — calls `x0/f.i()` to get current property value, then `x0/f.e()` to map to display string. Reads `SharedPreferences("app_prefs").getBoolean("auto_usb_peripheral", false)` to check if "auto" mode is active. Builds and dispatches `D0/i` to update the UI.
   - File: `/tmp/zsupport_decomp/smali/D0/k.smali`, line 117: `const-string v0, "Current USB mode: "`; line 215: `invoke-static {}, Lx0/f;->i()Ljava/lang/String;`

2. `D0/i.g()` — maps property value `"0"` → UI position 0, `"1"` → UI position 1. Sets the SegmentedButtonGroup position without triggering the listener (using the `z` AtomicBoolean guard). Logs "Unknown USB mode: X. Setting default to Peripheral." if value is unexpected.
   - File: `/tmp/zsupport_decomp/smali/D0/i.smali`, line 202: `const-string v5, "Unknown USB mode: "`

#### 7. "Auto USB Peripheral" feature

SharedPrefs key: `"auto_usb_peripheral"` in file `"app_prefs"`

- When enabled, the AUTO button (position 2) is selected and preference is saved via `x0/f.l(Context, boolean)` (smali line 1669).
- The `TimeZoneSyncReceiver` (BOOT_COMPLETED receiver) reads this preference and calls `x0/f.o("0")` on boot to force peripheral mode if the flag is set.
  - File: `/tmp/zsupport_decomp/smali/com/zsupport/helpers/TimeZoneSyncReceiver.smali`, line 554: `const-string v2, "0"` then `invoke-static {v2}, Lx0/f;->o(Ljava/lang/String;)Z`
  - Log on success: "USB mode switched to peripheral on system boot"

#### 8. Required permissions / signature level

**Critical**: The APK is signed with the **platform key**.

Evidence: `/tmp/zsupport_decomp/original/META-INF/PLATFORM.RSA` (and `PLATFORM.SF`) — this is the Android platform signing certificate used for system-signed apps.

In `AndroidManifest.xml`:
```xml
android:sharedUserId="android.uid.system"
```

This makes the app run in the `system` UID process. `setprop persist.*` properties are write-protected at the Linux DAC level — only root or processes with system UID (or a specific SELinux context) can write them. Without platform signing + `sharedUserId="android.uid.system"`, `setprop persist.usb.mode` will fail silently (non-zero exit code from the child process).

The only declared permission is `android.permission.RECEIVE_BOOT_COMPLETED` — the privilege comes entirely from the system UID, not from a manifest permission.

---

### Can Our App Replicate This?

**Yes, if and only if the app is platform-signed** (or has the equivalent SELinux context). The mechanism itself is extremely simple — a two-line shell exec. The hard part is the signing requirement.

Options for Zee Power Toys:

1. **Platform-sign the APK** — requires the Zeekr build keys. If our APK is already being installed as a system app (which the project context implies), this is the path to use. Add `android:sharedUserId="android.uid.system"` to `AndroidManifest.xml`, sign with the platform key, install to `/system/priv-app/`.

2. **Use `SystemProperties.set("persist.usb.mode", value)` via reflection** — this is the hidden API alternative to shelling out. It calls the native `property_set()` directly and avoids spawning a child process. Still requires system UID:
   ```kotlin
   val clazz = Class.forName("android.os.SystemProperties")
   val method = clazz.getMethod("set", String::class.java, String::class.java)
   method.invoke(null, "persist.usb.mode", "0")  // 0=peripheral, 1=host
   ```

3. **Root shell path** — if the device is rooted, `su -c "setprop persist.usb.mode 0"` would work without platform signing, but this is not the case for stock Zeekr DHU.

**Recommendation for implementation**: Use option 2 (reflection on `SystemProperties.set`) since it avoids spawning a child process and is what a properly privileged system app should do. Fall back to the `Runtime.exec` shell approach if reflection fails (matching zSupport's robustness pattern). Both require platform signing.

---

### Key Values Summary

| Property | Read | Write Peripheral | Write Host |
|---|---|---|---|
| `persist.usb.mode` | `getprop persist.usb.mode` | `setprop persist.usb.mode 0` | `setprop persist.usb.mode 1` |

| SharedPrefs file | Key | Type | Meaning |
|---|---|---|---|
| `app_prefs` | `auto_usb_peripheral` | Boolean | Auto-switch to peripheral on boot |

---

### ADB Enablement Path

The USB mode toggle enables **ADB over USB**: when `persist.usb.mode` is `"1"` (Host), the DHU's USB port acts as a USB host (like a computer), which allows a developer machine to connect another device. For ADB *to the DHU itself*, the mode should be **`"0"` (Peripheral)** — that is what makes the DHU visible to a connected PC as a USB peripheral so ADB works. Setting `"1"` (Host) makes the DHU act as the host, meaning ADB-over-USB *from* the DHU to something else.

So: **`persist.usb.mode = "0"` (Peripheral) = ADB target mode** (DHU is the ADB device). This is also the "Auto" boot behavior.


## Lift-ready artifacts

### x0/f (USB helper class)
- **Source:** `/tmp/zsupport_decomp/smali/x0/f.smali`
- **What:** Static utility class containing getUSBMode() (method i()), setUSBMode(String) (method o()), formatUsbMode(String) (method e()), setAutoUsbPeripheral(Context, boolean) (method l()), plus timezone helpers. Log tag: AnyAppSwitchUSBHelper
- **Reuse:** Port the two key methods directly to Kotlin. getUSBMode: Runtime.exec(['/system/bin/getprop', 'persist.usb.mode']) + readLine(). setUSBMode: Runtime.exec(['/system/bin/setprop', 'persist.usb.mode', mode]) + waitFor() + exitValue(). Prefer SystemProperties.set() via reflection as primary path with exec fallback. Values: '0'=peripheral, '1'=host.

### D0/f (SegmentedButton position change listener)
- **Source:** `/tmp/zsupport_decomp/smali/D0/f.smali`
- **What:** OnPositionChangedListener that maps UI button positions to mode strings and launches the set-USB-mode coroutine. Uses AtomicBoolean guard to distinguish programmatic vs user changes.
- **Reuse:** Port the position-to-mode mapping: position 0 or 2 -> '0' (peripheral), position 1 -> '1' (host). The guard pattern (AtomicBoolean z) prevents coroutine re-entry when the UI is updated programmatically. Replicate this in the Flutter->Kotlin bridge or ViewModel.

### TimeZoneSyncReceiver (boot auto-peripheral logic)
- **Source:** `/tmp/zsupport_decomp/smali/com/zsupport/helpers/TimeZoneSyncReceiver.smali`
- **What:** BOOT_COMPLETED BroadcastReceiver that reads SharedPrefs 'auto_usb_peripheral' from 'app_prefs' and calls setUSBMode('0') if true.
- **Reuse:** Add a BOOT_COMPLETED receiver in AndroidManifest.xml. On receipt, read SharedPreferences('app_prefs').getBoolean('auto_usb_peripheral', false). If true, call the setUSBMode equivalent with '0'. Requires android.permission.RECEIVE_BOOT_COMPLETED in manifest.

### activity_main.xml usbModeSwitcher layout
- **Source:** `/tmp/zsupport_decomp/res/layout/activity_main.xml`
- **What:** SegmentedButtonGroup with id 'usbModeSwitcher', 3 buttons: Peripheral (pos 0), Host (pos 1), AUTO (pos 2). Uses drawable baseline_usb_54, baseline_usb_off_54, baseline_autorenew_54.
- **Reuse:** Use as reference for the USB toggle UI widget. The three-state (Peripheral / Host / AUTO) design is the complete UX surface. In Flutter, a SegmentedButton with 3 segments replicates this. AUTO state stores 'auto_usb_peripheral'=true in SharedPrefs.


## Concrete API surface

- persist.usb.mode (system property, values: '0'=peripheral, '1'=host)
- /system/bin/setprop persist.usb.mode <value>
- /system/bin/getprop persist.usb.mode
- android.os.SystemProperties.set(String key, String val) [hidden API, reflection]
- android.os.SystemProperties.get(String key) [hidden API, reflection]
- android.uid.system (sharedUserId value in AndroidManifest.xml)
- SharedPreferences 'app_prefs' key 'auto_usb_peripheral' (boolean)
- android.intent.action.BOOT_COMPLETED (BroadcastReceiver trigger)
- android.permission.RECEIVE_BOOT_COMPLETED (manifest permission)
- com.zsupport.helpers.TimeZoneSyncReceiver (BOOT_COMPLETED receiver class)
- com.zsupport.MainActivity (single Activity, android:sharedUserId=android.uid.system)
- com.addisonelliott.segmentedbutton.SegmentedButtonGroup (USB mode UI widget)
- Log tag: AnyAppSwitchUSBHelper
- Log tag: AnyAppSupport (MainActivity tag)

## Risks

- Platform signature required: setprop persist.usb.mode is DAC+SELinux protected. Without android:sharedUserId='android.uid.system' AND platform key signing, the setprop child process will exit non-zero and the USB mode will not change. Our APK must be built with the Zeekr platform keys.
- SELinux policy may differ across Zeekr firmware versions: even with system UID, SELinux can block property writes. The specific domain for our app process must have 'set' permission for the 'usb_prop' property type. This needs validation on real hardware.
- Property value semantics on Zeekr: the mapping '0'=peripheral/'1'=host is inferred from zSupport's UI labels. If Zeekr's kernel/usb HAL uses different values or property names, the toggle will silently fail or cause incorrect mode. Must verify with adb shell getprop on a live DHU.
- Boot receiver timing: if the system property is applied before the USB gadget driver is initialized, the setprop call during BOOT_COMPLETED may be ignored. zSupport's approach relies on the driver reading the property at runtime; on some kernels it's only read at boot.
- No confirmation of ADB enablement: zSupport only writes persist.usb.mode, it does NOT explicitly enable ADB (persist.service.adb.enable=1). ADB availability over USB also depends on Developer Options being enabled and the USB debugging toggle. These are separate system properties/settings.
- Runtime.exec() approach is fragile in restricted SELinux contexts: spawning a child process with /system/bin/setprop may be blocked if the SELinux policy for our app domain lacks 'execute' permission for system_file. SystemProperties.set() via reflection is safer as it calls the native binder directly.
- Reflection on SystemProperties may break on future Android versions: hidden APIs are increasingly restricted. On API 32 (Android 12, which this APK targets per compileSdkVersion=32), the method is accessible but may be blocked by --hidden-api-policy in future Zeekr firmware updates.

## Open questions

- What is the actual persist.usb.mode value on a stock (unmodified) Zeekr DHU? Run: adb shell getprop persist.usb.mode. This confirms the property exists and the '0'/'1' mapping.
- Does Zee Power Toys already have platform signing set up? If the APK is installed as a system app, the build pipeline must supply the platform key. Confirm with the team.
- Is there a separate property or Settings.Global key that enables ADB debugging (persist.service.adb.enable or Settings.Global 'adb_enabled')? zSupport does not touch ADB enable/disable — is that already handled by system settings on the Zeekr?
- Does the Zeekr DHU SELinux policy allow the 'system_app' or 'platform_app' domain to write to usb-related properties? Need to check policy with: adb shell cat /sys/fs/selinux/policy | audit2allow or inspect sepolicy on device.
- Is 'Auto USB peripheral mode' (the AUTO third button) needed in Zee Power Toys, or is a simple Peripheral/Host toggle sufficient for the ADB use case?
- What happens to ADB connectivity when USB mode is toggled while a session is active? Is there a grace period or does the connection drop immediately?