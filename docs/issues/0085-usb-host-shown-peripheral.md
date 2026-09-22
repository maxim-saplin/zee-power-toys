---
status: tipped
labels: [usb]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [UsbAdbScreen, NativeUsbMode]
tier: T3
tip: 2c37c2e
---

# 0085 — USB mode UI shows Peripheral while actually Host

## Block scope
Car session: app USB screen showed Peripheral while device was Host (Maxim
switched Host via zSupport). UI must reflect the real USB role **on cold-open**
(force-stop → open app → USB screen) without launching zSupport again.

## Root cause
`NativeUsbMode` hard-defaulted `_currentMode = UsbMode.peripheral` and never called
`getRawUsbMode()` on startup or screen open. `_currentMode` only updated after a
successful `setUsbMode`. Cold-open therefore painted Peripheral whenever another
app (zSupport) had set `persist.usb.mode=1`.

## Tip (`2c37c2e`)
- `usbModeFromRaw` + `UsbModePort.refresh({autoPreferred})` syncs live prop → `currentMode`.
- `dhuMain` awaits `refresh` after constructing the port (`autoUsbPeripheral` from
  ConfigStore).
- `UsbAdbScreen` refreshes in `initState` and withholds the selector until ready
  (no wrong first paint).
- Tests: `usbModeFromRaw` / `FakeUsbMode.refresh` + cold-open widget (`liveRaw: '1'`).

## Definition of Done
- [x] Read actual USB role from system (not stale default) — tipped
- [ ] Car or instrumented T2 evidence Host vs Peripheral matches UI (PDM QA)
- [ ] PDM ACCEPT after double-check

## QA recipe (T3 / car)
1. With device in Host (`adb shell getprop persist.usb.mode` → `1`), force-stop
   Zee Power Toys (do **not** open zSupport).
2. Cold-open app → Settings → USB / ADB.
3. Screen must show **Host** selected / `Current: Host`, matching getprop —
   without launching zSupport.
4. Flip to Peripheral via zSupport, force-stop Zee, cold-open again → must show
   Peripheral.
