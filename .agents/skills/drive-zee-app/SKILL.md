---
name: drive-zee-app
description: Launch, drive, screenshot, and read state from the zee-power-toys app via the Feedback Loop (ADR 0004) on T1/T2/T3. Use when runtime-confirming a Block, verifying a feature works, injecting CarSignals, driving the DHU or HUD surface, taking screenshots, or running any ext.zee.* command.
---

# drive-zee-app

Operational front-end to the zee-power-toys Feedback Loop (ADR 0004).  For the
deep VM-service layer see
`docs/knowledge/flutter-debug-skill-vm-service.md`.  For the two-channel
routing contract see `docs/feedback-loop-contract.md`.

## Tiers

| Tier | Device | Launch device flag |
|------|--------|--------------------|
| T1   | Linux desktop — pure-Dart fakes, fastest iteration | `-d linux` |
| T2   | Android emulator `emulator-5554` — real native plumbing | `-d emulator-5554` |
| T3   | Zeekr car (DHU) — real AdaptAPI, real HUD optics | physical device |

---

## Launch — one command per tier

### T1 (desktop)

```bash
uv run dev/zee_run.py up
```

Writes flutter run stdout to `/tmp/zee_run_t1.log` (override with `$ZEE_RUN_LOG`),
polls until both dhu + hud surfaces answer `ext.zee.whoami`, then prints the VM
URI and persists it to `/tmp/zee_vm_uri.txt`.  Subsequent `feedback_loop.py` and
`zee_drive.py` commands read that file automatically — no `export ZEE_VM_URI`
required.  On success:

```
[zee_run] READY — both surfaces up
[zee_run] VM URI: ws://127.0.0.1:NNNNN/TOKEN=/ws
[zee_run] URI persisted → /tmp/zee_vm_uri.txt

Export for other tools (optional — driving tools read /tmp/zee_vm_uri.txt automatically):
  export ZEE_VM_URI='ws://127.0.0.1:NNNNN/TOKEN=/ws'
```

Driving tools (`dev/feedback_loop.py`, `dev/zee_drive.py`) pick up the URI from
`/tmp/zee_vm_uri.txt` automatically.  `export ZEE_VM_URI` is still respected as
an explicit override if you need to target a different session.

`zee_run.py down` deletes `/tmp/zee_vm_uri.txt` so stale URIs never shadow a
new session.

### T2 (Android emulator)

```bash
uv run dev/zee_run.py up --tier t2
```

Clears stale `adb forward --remove-all` first, then same wait-for-both-surfaces
protocol.  VM URI is discovered from `/tmp/zee_run_t2.log` and persisted to
`/tmp/zee_vm_uri.txt` (overwriting any previous tier's entry).

### Stop

```bash
uv run dev/zee_run.py down           # T1
uv run dev/zee_run.py down --tier t2 # T2
```

---

## Command cheatsheet

All commands below work after `zee_run.py up` (URI is read from
`/tmp/zee_vm_uri.txt` automatically).  `ZEE_VM_URI` is still accepted as an
explicit override.
Run with `uv run dev/feedback_loop.py <cmd>`.

### Core VM-service ops (every tier)

| What | Command |
|------|---------|
| Identity probe on both isolates | `uv run dev/feedback_loop.py whoami-all` |
| Raw state dump (DHU) | `uv run dev/feedback_loop.py dump-state --surface dhu` |
| Raw state dump (HUD) | `uv run dev/feedback_loop.py dump-state --surface hud` |
| Derived view-model (DHU) | `uv run dev/feedback_loop.py read-view-model --surface dhu` |
| Derived view-model (HUD) | `uv run dev/feedback_loop.py read-view-model --surface hud` |
| Write config | `uv run dev/feedback_loop.py set-config --surface dhu hudBoxOn=true` |
| Synthetic tap | `uv run dev/feedback_loop.py tap --surface dhu --key nav-minimap` |
| Screenshot DHU | `uv run dev/feedback_loop.py shot --surface dhu --out /tmp/dhu.png` |
| Screenshot HUD | `uv run dev/feedback_loop.py shot --surface hud --out /tmp/hud.png` |
| Inject CarSignal (T1 only — VM-service path) | `uv run dev/feedback_loop.py inject kind=blinker value=left` |
| Drive minimap (T2/T3) | `uv run dev/feedback_loop.py minimap on=true x=0 y=0 w=640 h=360` |

### Full ext.zee.* surface (12 extensions)

All 12 are in `lib/debug/agent_extensions.dart`.  The `feedback_loop.py`
subcommands cover the most-used ones; the rest go via the generic `call` form:

```bash
uv run dev/zee_drive.py call ext.zee.<name> --isolate dhu|hud [k=v ...]
```

| Extension | Surface | Params | Returns | Notes |
|-----------|---------|--------|---------|-------|
| `ext.zee.whoami` | both | — | `{surface, isolate, pid, hudBoxOn, hudEnabled}` | Identity probe; driver builds surface→isolateId map from this |
| `ext.zee.dumpState` | both | — | `{surface, hudBoxOn, hudEnabled, locale, safeArea, blinker, battery, minimap}` | Raw ConfigStore snapshot |
| `ext.zee.readViewModel` | both | — | full view-model incl. CarSignals snapshot, safeArea, activeSlots, minimap, systemLocale, usbMode | Derived Riverpod state |
| `ext.zee.setConfig` | both | `hudBoxOn=true\|false`, `hudEnabled=`, `safeArea=<json>`, `safeLeft/Top/Right/Bottom=<f>`, `blinkerShape=dots\|arrows\|smiley`, `blinkerSize=<f>`, `batteryShow=`, `tempShow=`, `chargingShow=`, `locale=en\|ru\|system`, `minimapEnabled=`, `minimapPreset=compact\|balanced\|large`, `minimapTheme=auto\|dark\|light` | dumpState snapshot | Writes to ConfigStore; DHU→HUD relay fires automatically |
| `ext.zee.tapByKey` | both | `key=<ValueKey string>` | `{tapped, key, mode\|x,y}` | Three-tier fallback: callback→pointer→ancestor |
| `ext.zee.shot` | both | — | `{surface, w, h, png_b64}` | RepaintBoundary→PNG→base64 |
| `ext.zee.inject` | dhu | `kind=speed value=<kmh>`, `kind=blinker value=left\|right\|hazard\|off`, `kind=charge charging=true\|false kw=<f> volts=<f> amps=<f>`, `kind=battery levelPct=<i> tempC=<f>`, `kind=powerFlow value=drive\|regen\|standstill\|unknown` | CarSignals snapshot | DHU only (FakeCarSignals); HUD CarSignals are relay-driven — always inject on dhu so both surfaces update. T2/T3 use ADB broadcast |
| `ext.zee.minimap` | dhu | `on=true\|false`, `x=<f> y=<f> w=<f> h=<f>`, `key=<k> value=<v>` | `{surface, minimap, on}` | Registered whenever a MinimapHost is present — `FakeMinimapHost` on T1, `NativeMinimapHost` on T2/T3 |
| `ext.zee.install` | dhu | `target=launcher\|ynavi` OR `repo=<r> branch=<b> path=<p>` | `{surface, install:{target, started}}` | Triggers install; poll `read-view-model` for live progress |
| `ext.zee.setLanguage` | dhu | `scope=app\|system\|cluster value=en\|ru\|system` | `{ok, reason?, surface, scope, value, systemLocale?}` | `scope=system\|cluster` is T3-only; T1/T2 returns `{ok:false, reason:"unsupported-on-device"}` |
| `ext.zee.setUsbMode` | dhu | `value=peripheral\|host\|auto` | `{ok, reason?, usbMode, usbWritable}` | T1 FakeUsbMode always writable; T2 needs platform signing |
| `ext.zee.bootState` | both | — | `{surface, hudEnabled, configReadOk, …native fields}` | DHU Android includes native FGS status; T1/HUD config-store only |

### Generic call form examples

```bash
# Read boot state
uv run dev/zee_drive.py call ext.zee.bootState --isolate dhu

# Set language (app locale)
uv run dev/zee_drive.py call ext.zee.setLanguage --isolate dhu scope=app value=ru

# Set USB mode (T1 fake)
uv run dev/zee_drive.py call ext.zee.setUsbMode --isolate dhu value=host

# Trigger fake install and watch progress
uv run dev/zee_drive.py call ext.zee.install --isolate dhu target=launcher
uv run dev/feedback_loop.py read-view-model --surface dhu   # check .install.phase
```

### T2 inject via ADB broadcast (bypasses VM-service)

```bash
adb shell am broadcast \
  -n com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver \
  -a com.zeepowertoys.SIMULATE --es kind blinker --es value left
```

Or via feedback_loop.py with `--tier t2`:

```bash
uv run dev/feedback_loop.py --tier t2 inject kind=blinker value=left
```

---

## Surface resolution

Both Dart isolates are named `main` and share a `rootLib`.  Never use
`isolates[0]` to target a surface.  The driver calls `ext.zee.whoami` on each
isolate and matches the `surface` field (`"dhu"` or `"hud"`).

`FeedbackLoop.connect()` in `feedback_loop.py` polls `getVM` until both
surfaces answer before dispatching any surface-targeted op (HUD engine starts
after DHU's first frame — ADR 0004 §21).

---

## Recipes

### Toggle HUD box and confirm both surfaces re-derive

```bash
# Enable HUD box via DHU (setConfig works from any screen)
uv run dev/feedback_loop.py set-config --surface dhu hudBoxOn=true
# Confirm HUD isolate sees the relay
uv run dev/feedback_loop.py dump-state --surface hud   # hudBoxOn should be true
# Toggle back
uv run dev/feedback_loop.py set-config --surface dhu hudBoxOn=false
uv run dev/feedback_loop.py dump-state --surface hud   # hudBoxOn should be false
```

### Tap a navigation button (settings home screen)

```bash
# Navigate to minimap settings
uv run dev/feedback_loop.py tap --surface dhu --key nav-minimap
# Toggle minimap enable (on that screen)
uv run dev/feedback_loop.py tap --surface dhu --key minimap-enable-toggle
```

Note: `tapByKey` only succeeds when the keyed widget is in the LIVE widget tree (i.e., its screen is mounted).  Navigate to the relevant screen first.

Available keys on the settings home screen: `nav-hud`, `nav-minimap`, `nav-diagnostics`, `nav-language`, `nav-install`, `nav-usb`, `nav-simulate` (debug builds only).  Keys on minimap settings: `minimap-enable-toggle`, `minimap-preset-compact`, `minimap-preset-balanced`, `minimap-preset-large`.  HUD settings screen key: `safe-area-inset-slider`, `blinker-shape-dots`, `blinker-shape-arrows`, `blinker-shape-smiley`.  USB/ADB screen (nav-usb): `usb-mode-selector`, `usb-peripheral`, `usb-host`, `usb-auto`.  Simulate screen (nav-simulate, Block 0026): `simulate-blinker-off`, `simulate-blinker-left`, `simulate-blinker-right`, `simulate-blinker-hazard`, `simulate-charging-toggle`.

### Inject blinker then screenshot the HUD

```bash
uv run dev/feedback_loop.py inject kind=blinker value=left
uv run dev/feedback_loop.py shot --surface hud --out /tmp/hud-blinker.png
```

### Runtime-confirm an install (T1 FakeInstaller)

```bash
uv run dev/zee_drive.py call ext.zee.install --isolate dhu target=launcher
# Poll until done
uv run dev/feedback_loop.py read-view-model --surface dhu   # .install.phase = 'done'
```

### Change app language and screenshot

```bash
uv run dev/zee_drive.py call ext.zee.setLanguage --isolate dhu scope=app value=ru
uv run dev/feedback_loop.py shot --surface dhu --out /tmp/dhu-ru.png
```

### Read boot state

```bash
uv run dev/zee_drive.py call ext.zee.bootState --isolate dhu
```

---

## Hazards

1. **Cadence ≤5 mutating RPCs/s.** Each costs ~140 ms; >7/s queues responses
   until the connection looks wedged.  Space writes by at least 200 ms.
2. **Never force-stop a live flutter run** (`adb shell am force-stop`,
   `pm clear`, `pm revoke`).  Causes `Lost connection` and a 60–90 s rebuild.
3. **WSL2 hot reload is unreliable** (inotify doesn't fire on WSL2 paths).
   After editing `dev/` code, run `dev/zee_run.py down && dev/zee_run.py up`
   rather than expecting hot reload to pick up changes.
4. **Two-engine startup race.** The HUD isolate is created after DHU's first
   frame.  `zee_run.py up` already handles this — but if you call `feedback_loop.py`
   immediately after manually starting flutter run, poll until both surfaces
   resolve (the tool retries automatically via `_build_surface_map`).
5. **Release builds have NO extensions.** Extensions are stripped by
   `kDebugMode`.  Always use `flutter run` (debug) or `--profile`; never a
   release APK.
6. **Stale adb forwards.** `zee_run.py up --tier t2` calls
   `adb forward --remove-all` automatically.  If you start flutter run manually,
   run `adb forward --remove-all` first to avoid port conflicts.

---

## References

- `docs/feedback-loop-contract.md` — two-channel routing table + inject kinds
- `docs/knowledge/flutter-debug-skill-vm-service.md` — deep VM-service reference
- `dev/zee_drive.py` — low-level VMClient + URI discovery
- `dev/feedback_loop.py` — tier-agnostic semantic ops
- `dev/zee_run.py` — launcher (this skill's primary entry point)
- `lib/debug/agent_extensions.dart` — authoritative Dart-side extension source
- ADR 0004: `docs/adr/0004-dual-channel-feedback-loop.md`
