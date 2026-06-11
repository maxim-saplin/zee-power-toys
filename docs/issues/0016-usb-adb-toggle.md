---
status: done
labels: [app-shell, research, usb-adb]
created: 2026-06-11
satisfies: Research · zSupport decompile → USB host/peripheral ADB toggle (spike)
blocked-by: [0011]
modules: [SystemConfig]
tier: T2
---

# 0016 — USB host/peripheral ADB toggle (zSupport spike → implementation)

## Block scope
Spike outcome of decompiling `zSupport-1.3.5-release.apk` → a guarded **USB-mode toggle** (Peripheral / Host / Auto) that flips `persist.usb.mode` to enable ADB-over-USB to the DHU. The decompile is already done (research). The real write is **platform-signing-gated (T3)** — exactly like the cluster-language write — so deliver the mechanism + UI + honest T3 deferral, verify the off-car guard on T2.

## Touches
- **Satisfies:** REQUIREMENTS — "Investigate/decompile zSupport… discover how it controls ADB (enabling/disabling USB Host/Peripheral via UI…)."
- **Modules:** SystemConfig (or a small UsbMode adapter).
- **ADRs:** 0002, 0003.

## Grounding — the decompile is DONE
- Full findings: [`docs/knowledge/zsupport-usb-adb-toggle.md`](../knowledge/zsupport-usb-adb-toggle.md). Mechanism: `persist.usb.mode` = `0` (peripheral = ADB-target) / `1` (host); zSupport shells `setprop`; prefer `android.os.SystemProperties.set` via reflection (exec fallback). Requires platform key + `sharedUserId=android.uid.system`. Auto-peripheral-on-boot via a SharedPrefs flag + BOOT_COMPLETED.

## What to build
- Promote the findings to a proper spike doc `docs/spikes/usb-adb-toggle.md` (concise: mechanism, values, signing requirement, our implementation path, open questions). Link from `docs/knowledge/README.md`.
- **UsbMode capability**: a port method (extend `SystemConfig` or a small `UsbModeController`) `getUsbMode()` / `setUsbMode(peripheral|host|auto)` via `SystemProperties.set("persist.usb.mode", "0"|"1")` reflection (guarded; exec fallback). On the emulator (not platform-signed) the set returns `{ok:false, reason:"requires-platform-signing"}` — never crash; `getUsbMode` reads the current value (may be empty). Auto stores a SharedPrefs flag and is applied on boot by the existing BootReceiver (0010).
- **UI**: a small "USB / ADB" section (in the Diagnostics screen or a Developer subsection) — a 3-state selector (Peripheral / Host / Auto) showing the current mode + the outcome; disabled+explained ("requires platform signing — works on the car") when unsupported. Localized.
- `ext.zee.*`: `setUsbMode value=peripheral|host|auto` + readViewModel `{usbMode, usbWritable}`.

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] Spike doc written. — artifact: `docs/spikes/usb-adb-toggle.md`.
- [x] **T1:** USB/ADB selector renders (Peripheral/Host/Auto), localized; the Fake reflects the chosen mode. — artifact: `shots/usb-adb.png` ("Current: Host", Host segment selected); readViewModel `{usbMode:host, usbWritable:true}`.
- [x] **T2:** `setUsbMode` runs both the reflection AND `/system/bin/setprop` paths, both fail with SELinux denial → `{ok:false, reason:"requires-platform-signing"}` (no crash; 2 isolates still alive); `usbWritable` flips false after the first failed write; `getprop persist.usb.mode` empty on the emulator. — artifact: logcat (AVC denial) + readViewModel.
- [x] analyze clean; tests green; build linux+apk ok. Principles: honest about T3; no crash; clear UX.

## Reconciliation
Built by Sonnet, runtime-verified by the orchestrator (Opus), 2026-06-11.
1. **Mechanism (from the decompile):** `persist.usb.mode` = `0` (peripheral = ADB-target) / `1` (host); `SystemProperties.set` via reflection, `/system/bin/setprop` exec fallback. The real write needs the **platform key + `sharedUserId=android.uid.system`** (T3); on the emulator both paths hit an SELinux `property_service` denial and the adapter returns `requires-platform-signing` — never faked.
2. **`persist.usb.mode` does not exist on the stock emulator** (it uses `persist.sys.usb.config`/`sys.usb.config`) — consistent with the spike's open question; the real value must be confirmed on the DHU (T3).
3. **Auto** stores a flag applied on boot by the existing BootReceiver (0010). The toggle UI lives in the Diagnostics screen's USB/ADB section.
