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

T1 is Linux-only — `dev/zee_run.py:372` hardcodes `flutter run -d linux`, and there is no
`macos/` runner directory, so it will not launch on a macOS host. On macOS, use `flutter test`
for the fast loop and treat T2 as the truth tier for anything touching the native edge. T1
also runs against `FakeMinimapHost` (not `NativeMinimapHost`), so it structurally cannot
verify the Minimap on any host — that always needs T2 or T3.

---

## Launch — one command per tier

### T1 (desktop)

```bash
uv run dev/zee_run.py up
```

Writes flutter run stdout to `/tmp/zee_run_t1.log` (override with `$ZEE_RUN_LOG`),
polls until both dhu + hud surfaces answer `ext.zee.whoami`, then prints the VM
URI and persists it to `/tmp/zee_vm_uri_t1.txt`.  Subsequent `feedback_loop.py` and
`zee_drive.py` commands read that file automatically — no `export ZEE_VM_URI`
required.  On success:

```
[zee_run] READY — both surfaces up
[zee_run] VM URI: ws://127.0.0.1:NNNNN/TOKEN=/ws
[zee_run] URI persisted → /tmp/zee_vm_uri_t1.txt

Export for other tools (optional — driving tools read /tmp/zee_vm_uri_t1.txt automatically):
  export ZEE_VM_URI='ws://127.0.0.1:NNNNN/TOKEN=/ws'
```

Driving tools (`dev/feedback_loop.py`, `dev/zee_drive.py`) pick up the URI from
the per-tier session file automatically (QA3-5: `/tmp/zee_vm_uri_t1.txt` /
`_t2.txt` — no more one shared file, so a T2 launch can no longer shadow a
live T1 session). `export ZEE_VM_URI` is still respected as an explicit
override if you need to target a different session.

`zee_run.py down` deletes `/tmp/zee_vm_uri_t1.txt` so a stale URI never
shadows a new session.

### T2 (Android emulator)

```bash
uv run dev/zee_run.py up --tier t2
```

Runs `preflight --fix` first (see below), clears stale `adb forward
--remove-all`, then the same wait-for-both-surfaces protocol, with one added
self-heal step (see "Self-heal" below). VM URI is discovered from
`/tmp/zee_run_t2.log` and persisted to `/tmp/zee_vm_uri_t2.txt`.

### `preflight` — device readiness BEFORE `flutter run` (auto-run by `up --tier t2`)

```bash
uv run dev/zee_run.py preflight --tier t2 [--fix]
```

The overlay display must exist *before* `flutter run` starts — if it's
missing, the native HUD engine never spawns and `up` times out at 60s with no
useful message. `preflight` checks, in order: adb reachable; `dumpsys
display`'s `Overlay #1` device resolves at `1024x576/213` (NOT via
`zee_drive.resolve_hud_display()` — that needs a live Presentation already
attached, which doesn't exist yet at preflight time; see
`overlay_display_geometry()`'s docstring); and reports `hudEnabled` read
straight from `adb shell run-as com.zeepowertoys.zee_power_toys cat
shared_prefs/FlutterSharedPreferences.xml` (no VM session needed). Exits
non-zero with a `remedy` field on failure. `--fix` clears then re-applies
`overlay_display_devices` (a `settings put` with an *unchanged* value does
not reliably re-fire display creation, observed live) and polls until the
display reappears — this destroys/recreates the display, so it must run
BEFORE `flutter run`, never against a live session.

### Self-heal — the `hudEnabled=false` trap

`hudEnabled=false` is an unrecoverable trap on its own: `MainActivity.kt`'s
`setupHud()` gate skips spawning the HUD engine entirely, so `hud` never
answers `ext.zee.whoami` and `up --tier t2` would otherwise time out at 60s
with nothing to recover it. `up` checks after ~20s: if only `dhu` has
answered and its own `whoami` reports `hudEnabled=false`, it calls
`ext.zee.setConfig hudEnabled=true`, then runs `down`+`up` **once** more
(guarded so it can never loop — pass `--no-self-heal` to disable and just
time out normally instead). Turns a silent 60s hang into a ~40s automatic
recovery using only existing extensions.

### Stop

```bash
uv run dev/zee_run.py down           # T1
uv run dev/zee_run.py down --tier t2 # T2
```

`down` also `adb shell am force-stop`s the app on-device for T2 — the pgid
kill alone only stops the *host-side* `flutter run` process group and used to
leave the app itself running on the device. Safe here specifically because
`flutter run` is already dead by that point (see Hazard 2 below).

---

## Command cheatsheet

All commands below work after `zee_run.py up` (URI is read from
`/tmp/zee_vm_uri_<tier>.txt` automatically — pass `--tier`/`--tier t2` to the
driving tools so they read the right one; per-tier files replaced one shared
file so a T2 launch no longer shadows a live T1 session, QA3-5).  `ZEE_VM_URI`
is still accepted as an explicit override.  A file-sourced URI is
liveness-probed (`getVersion`) before use; a stale one (pointing at a dead
port from a killed session) is deleted automatically and discovery falls
through instead of hanging on the RPC timeout.
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
| Screenshot HUD, native composite | `uv run dev/feedback_loop.py shot --surface hud --layer native --out /tmp/hud-native.png` |
| Discover the HUD display | `uv run dev/feedback_loop.py hud-display` |
| Inject CarSignal (T1 only — VM-service path) | `uv run dev/feedback_loop.py inject kind=blinker value=left` |
| Drive minimap (T2/T3) | `uv run dev/feedback_loop.py minimap on=true x=0 y=0 w=640 h=360` |

> ⚠️ **`shot --surface hud` (default `--layer flutter`) CANNOT see the map.**
> The HUD is a transparent Flutter `RepaintBoundary` composited by Android
> **on top of** a native `MinimapView` TextureView that YNavi paints into.
> `ext.zee.shot` captures the Flutter layer only — the native map is
> structurally invisible to it. This is exactly why a minimap regression
> shipped undetected once already; see
> [`docs/issues/0009-minimap-under-layer.md:39`](../../../docs/issues/0009-minimap-under-layer.md).
> **Whenever the minimap/native composite matters, use `--layer native` or
> `--layer both` — never trust a bare `--layer flutter` shot of the HUD to
> prove the map renders.**

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
| `ext.zee.readViewModel` | both | — | full view-model incl. CarSignals snapshot, safeArea, activeSlots, minimap, systemLocale, usbMode, `hud` ({displayId,w,h,dpi}), `viewport` ({x,y,w,h}) | Derived Riverpod state; `hud`/`viewport` (Block 0027, DHU only) are the app's own HUD geometry + minimap ROI — use them to crop the native composite exactly, never reimplement the geometry in Python |
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

## Native composite capture — `shot --layer` (Block 0027)

`ext.zee.shot` (the default, `--layer flutter`) captures **only** the Flutter
`RepaintBoundary`. On the HUD surface the native `MinimapView` TextureView —
the actual map — is composited by Android *underneath* the transparent
Flutter overlay, so it is structurally invisible to that capture. This is
documented in [`docs/issues/0009-minimap-under-layer.md:39`](../../../docs/issues/0009-minimap-under-layer.md)
and is the reason a minimap regression once shipped undetected: the
verification harness could not see the thing it was supposed to verify.

`dev/feedback_loop.py shot` now takes a `--layer` flag:

| `--layer` | What it captures | Needs a VM session? |
|-----------|-------------------|----------------------|
| `flutter` (default) | `ext.zee.shot` RepaintBoundary only — **cannot see the native map** | yes |
| `native` | Full device composite via `adb exec-out screencap -p -d <displayId>` — sees everything actually on screen | **no** — pure adb |
| `both` | Both: native → `--out`, flutter → `--out.flutter.png`; reports both dimension pairs | yes (for the flutter half) |

```bash
# Full composite (map + Flutter overlay) — the ONLY capture that proves the map renders.
uv run dev/feedback_loop.py shot --surface hud --layer native --out /tmp/hud.png

# Both, for side-by-side comparison (native will be larger — physical px vs logical px).
uv run dev/feedback_loop.py shot --surface hud --layer both --out /tmp/hud.png

# Assert the native capture's dimensions (fails loudly on a wrong/missing display).
uv run dev/feedback_loop.py shot --surface hud --layer native --out /tmp/hud.png --expect 1024x576
```

`--expect WxH` parses the captured PNG's own IHDR chunk and asserts it
matches; on a mismatch nothing is written and the command exits non-zero with
`{"error": "dimension mismatch", "got": [...], "want": [...]}`.  This is the
real guard — never hardcode the expected displayId, only the expected pixel
dimensions returned by the capture itself.

### `hud-display` — discover the HUD's logical display id

```bash
uv run dev/feedback_loop.py hud-display
```

Parses `adb shell dumpsys display` for the first secondary `DisplayViewport`
(`displayId != 0`) and its `densityDpi` (from the `DisplayDeviceInfo` block
named "Overlay"). Returns `{displayId, w, h, dpi, name}`. Pure adb — no VM
session needed, works even before the app is launched. Do **not** hardcode
displayId 2: `screencap -h` documents `-d` as a *physical* display id and
`dumpsys SurfaceFlinger --display-id` only lists display 0 even though the
secondary display is real and working — discover it fresh each time, and
still assert the *returned PNG's* dimensions after capture.

If no secondary display is found, the remedy is:
```bash
adb shell settings put global overlay_display_devices "1024x576/213"
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

## Getting the real YNavi map onto the T2 HUD (`dev/ynavi_prep.py`)

Stock YNavi will **not** render on the HUD.  The mod must include the P9
Yandex-Plus (`HasPlus`) patch or `setSurfaceCallback` never fires — you get a
silent no-map (bind succeeds, lifecycle completes, no surface).  See
`docs/knowledge/ynavi-bind-and-mod.md` for the full patch inventory and
`docs/knowledge/phase0-ynavi-ab-testing.md` for why only one CarApp host may
bind to `NavigationCarAppService` at a time (and the manual reset sequence
this script automates).

`dev/ynavi_prep.py` turns that manual, easy-to-get-wrong sequence into one
command.  **Run it before `zee_run.py up --tier t2`** — steps 3-4 below
force-stop the competing CarApp host and will kill a live Flutter session.

```bash
uv run dev/ynavi_prep.py [--serial emulator-5554] [--apk PATH] \
    [--via-app] [--skip-install] [--verify]
```

Runbook — what it does, in order:

1. **Guard (non-negotiable).** Refuses to run if `/tmp/zee_run_t2.pid` names a
   live pid, or `/tmp/zee_vm_uri_t1.txt`/`_t2.txt` exists (a `zee_run.py`
   session URI is persisted; only `zee_run.py down` removes it).  Remedy
   printed on refusal: `uv run dev/zee_run.py down --tier t2`.
2. **Install the modded APK** — `adb install -r` (retries `-r -d` on
   `INSTALL_FAILED_VERSION_DOWNGRADE`; uninstalls + reinstalls on a signature
   mismatch).  Auto-discovers a local clone at
   `<repo>/../ynavi-zee/modded_apks/zeekr_signed_v11.apk`, matching the
   published coordinates in `lib/services/install_targets.dart:23-27`
   (`maxim-saplin/ynavi-zee`, branch `speedcam`).  Pass `--apk PATH` to
   override, or `--skip-install` if already installed.
   `--via-app` drives `ext.zee.install target=ynavi` through an
   **already-live** session instead of `adb install` — this directly
   contradicts step 1's guard, so it is a documented-but-secondary path: it
   performs the install only, then tells you to stop the session
   (`zee_run.py down --tier t2`) and re-run with `--skip-install` to finish
   steps 3-6.
3. `am force-stop ru.yandex.yandexnavi` + `pm clear ru.yandex.yandexnavi` +
   `am force-stop com.zeepowertoys.zee_power_toys` (the competing CarApp
   host — see `docs/knowledge/phase0-ynavi-ab-testing.md`'s reset sequence).
4. Re-grant `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` (`pm clear`
   wipes all runtime grants).
5. **Verify the mod is detectable** — `pm dump ru.yandex.yandexnavi | grep -i
   NavigationCarAppService`, mirroring `MainActivity.kt`'s native
   `isYnaviAvailable()` check (`:638-666`) without needing the app running.
   Gated on `pm path` confirming the package is installed *first* — see the
   gotcha below.
6. **Prints the exact next commands**, including the one that's easy to
   forget: `minimap.enabled` defaults to `false` in persisted config
   (`lib/services/config_store.dart` `MinimapConfig(enabled: false)`), so the
   map will not appear until you set it:
   `uv run dev/feedback_loop.py set-config --surface dhu minimapEnabled=true`.
7. **`--verify`** chains: prep → `zee_run.py up --tier t2` → enable the
   minimap → `feedback_loop.py shot --surface hud --layer native --out
   /tmp/ynavi-verify.png --expect 1024x576` → read `.minimap.ynaviAvailable`
   from `read-view-model --surface dhu` (minimap host — and therefore
   `ynaviAvailable` — is only registered on the `dhu` surface).  The script
   can only report these *signals*; a human/agent must still open the PNG —
   a correctly-sized placeholder still passes the dimension check but is not
   a map.

**Real gotcha hit while building this (not hypothetical):** on this
emulator, `pm dump <pkg>` does **not** cleanly filter to the queried
package — it appends a system-wide process-stats history section that
mentions *any* process that ever ran under that name, even long after
uninstall.  Grepping that output alone for `NavigationCarAppService` gives a
false "detected" result even when the package is currently absent.
`ynavi_prep.py` gates step 5's grep on `pm path` (a definitive
"installed right now" signal) before trusting it — don't regress that gate
if you touch this code.

Idempotent and re-runnable — every step is safe to repeat.

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

## `zee_gate.py` — the Definition-of-Done gate

**A Block's Definition of Done quotes `zee_gate.py`'s JSON — not a PNG path.**
26 delivery Blocks in this repo were signed off as "runtime-confirmed with an
attached screenshot" while the app was visibly broken, because a screenshot
only proves a PNG *exists*, never that anything was actually *compared*
against a threshold or a prior good state. `dev/zee_gate.py` composes the
pieces that already existed (`zee_pixels.py`'s metrics, `zee_diff.py`'s
`readable`/`differs`/`same`/`ab`, `shot --layer native`) into one command a
sign-off can quote directly.

```bash
uv run dev/zee_gate.py --tier t2
uv run dev/zee_gate.py --tier t2 --checks env,surfaces,relay,hud-visible,minimap-readable,shape-geometry
uv run dev/zee_gate.py --tier t2 --baseline /tmp/gate-base    # record this run's captures+metrics
uv run dev/zee_gate.py --tier t2 --against /tmp/gate-base     # compare against a recorded baseline
```

JSON is always printed to stdout; exit code is non-zero if any check (or
baseline comparison) fails.

| check | what it does |
|---|---|
| `env` | emulator reachable; `overlay_display_devices == "1024x576/213"`; secondary display resolves (`zee_drive.resolve_hud_display()`); reports `hudEnabled` from the persisted config |
| `surfaces` | both `dhu` and `hud` answer `ext.zee.whoami` |
| `relay` | `set-config --surface dhu blinkerShape=smiley` → HUD `dumpState` reflects it → set back to `arrows`. Replaces the deleted `verify_skeleton.py`'s relay check, which targeted the long-removed `hudBoxOn` field. A 1.5s settle follows the last mutation — any `ext.zee.setConfig` write, even one unrelated to the minimap, momentarily drops the native minimap to its "no fix" grid placeholder before it re-settles; without the settle a pixel check running right after `relay` in the same invocation can catch that placeholder and misreport an unreadable/all-black HUD |
| `hud-visible` | native composite of the HUD display; `inkFrac > --min-ink-frac` (default **0.01**, not the `0.02` one might reach for first — see the `DEFAULT_MIN_HUD_VISIBLE_INK_FRAC` comment in the source for the measured calibration: post-Block-0025 the minimap is confined to a small Safe-Area square rather than full-bleed, so even a fully-loaded healthy HUD frame tops out around inkFrac 0.017-0.019 whole-frame). Fails on an all-black HUD — the failure mode nobody was catching |
| `minimap-readable` | ROI from `read-view-model`'s `viewport` (never hardcoded); delegates to `zee_diff.py`'s `readable` thresholds incl. `colorGlowFrac`. Refuses to grade a *disabled* minimap — reports `"skipped": true` and fails outright instead of vacuously passing on whatever else occupies that ROI rectangle (minimap defaults OFF) |
| `shape-geometry` | `flutter test test/hud/` |

`--baseline DIR` records the `hud-visible`/`minimap-readable` captures plus
their metrics into `DIR/metrics.json` + `DIR/*.png`. `--against DIR` re-crops
the current run's captures to the same ROI and compares pixel-for-pixel via
`zee_pixels.compare()`; a regression is either a captured `pass` flipping
true→false since the baseline, or `changedFrac` exceeding
`zee_diff.DEFAULT_MAX_CHANGED_FRAC_SAME` (0.01) — a real visual change, even
one that still clears the absolute thresholds. This comparison is the
primitive the previous 26 Blocks lacked: an existence-only screenshot cannot
catch "this used to look different." Prefer `--checks hud-visible,minimap-
readable` for baseline/against pairs — the live map is genuinely animating
(driving simulation, tile loads), so keeping both captures close in time
avoids mistaking ordinary map drift for a regression; `shape-geometry`'s
`flutter test` alone can add 5-10s between captures.

---

## Hazards

1. **Cadence ≤5 mutating RPCs/s.** Each costs ~140 ms; >7/s queues responses
   until the connection looks wedged.  Space writes by at least 200 ms.
2. **Never force-stop a live flutter run** (`adb shell am force-stop`,
   `pm clear`, `pm revoke`).  Causes `Lost connection` and a 60–90 s rebuild.
   `zee_run.py down` DOES `am force-stop` the app on-device, but only *after*
   killing the host-side `flutter run` process group — by that point the
   session is already dead, so this isn't the hazard; it's cleanup of the
   leak that hazard would otherwise leave behind (the pgid kill alone never
   touched the on-device app process).
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
7. **YNavi prep must run BEFORE `zee_run.py up --tier t2`, never after or
   alongside.** `dev/ynavi_prep.py` force-stops
   `com.zeepowertoys.zee_power_toys` (step 3) — running it against a live
   Flutter session is exactly hazard #2 above.  Its own guard refuses to run
   if `/tmp/zee_run_t2.pid` or `/tmp/zee_vm_uri_{t1,t2}.txt` indicates a live
   session — do not bypass that guard manually.
8. **`pm dump <pkg>` is not reliably package-scoped for detection checks.**
   On the T2 emulator it appends system-wide process-stats history that can
   mention a service from a *previous* install of an already-uninstalled
   package.  Always gate a `pm dump | grep` detection on `pm path <pkg>`
   (or `pm list packages`) confirming the package is installed *first* — see
   `dev/ynavi_prep.py`'s `verify_mod_detectable()`.
9. **Any `ext.zee.setConfig` write briefly drops the native minimap to its
   "no fix" grid placeholder**, even a write to a field unrelated to the
   minimap (observed live: toggling `blinkerShape`) — ConfigStore pushes the
   whole config object through on every write, which re-triggers the native
   minimap-apply path regardless of which field changed. Wait for it to
   re-settle (`zee_gate.py`'s `relay` check waits 1.5s) before trusting a
   pixel capture that follows a config mutation.
10. **Changing `overlay_display_devices` to an unchanged value does not
    reliably re-fire display creation.** If the secondary display exists but
    is in a bad state, `settings put` with the *same* string can be a no-op —
    clear it first (`settings put global overlay_display_devices ""`), then
    set it, and poll `dumpsys display` until the display reappears. See
    `zee_run.py preflight --fix`.

---

## References

- `docs/feedback-loop-contract.md` — two-channel routing table + inject kinds
- `docs/knowledge/flutter-debug-skill-vm-service.md` — deep VM-service reference
- `docs/knowledge/phase0-ynavi-ab-testing.md` — YNavi reset sequence + why
  only one CarApp host may bind at a time
- `docs/knowledge/ynavi-bind-and-mod.md` — YNavi mod patch inventory (P1-P9),
  bind/handshake protocol, surface handover
- `docs/issues/0019-ynavi-map-render.md` — the working render recipe
- `dev/zee_drive.py` — low-level VMClient + URI discovery
- `dev/feedback_loop.py` — tier-agnostic semantic ops
- `dev/zee_run.py` — launcher (this skill's primary entry point); `preflight`
  subcommand + self-heal live here
- `dev/zee_gate.py` — the Definition-of-Done gate (see its own section above)
- `dev/zee_pixels.py` — pixel metrics/comparison primitives (no I/O/VM/adb dep)
- `dev/zee_diff.py` — the pixel comparison CLI (`selftest`/`metrics`/`readable`/`differs`/`same`/`ab`)
- `dev/ynavi_prep.py` — one-command YNavi mod install + reset + detect for T2
- `docs/issues/BACKLOG.md` — QA3-5 (per-tier URI files, now fixed)
- `lib/debug/agent_extensions.dart` — authoritative Dart-side extension source
- ADR 0004: `docs/adr/0004-dual-channel-feedback-loop.md`
