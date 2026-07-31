# ext.zee.* Surface Contract

Every driveable surface in zee-power-toys MUST implement the following
`ext.zee.*` VM-service extensions.  Surfaces are identified by the `surface`
field returned by `ext.zee.whoami` — not by isolate name (both isolates are
named `main`, per ADR 0004).

---

## Required extensions

The app registers **12** `ext.zee.*` extensions (`lib/debug/agent_extensions.dart`).
Eight are present on **every** surface; four are DHU-only and registered only when
their backing port is injected (so the surface map degrades cleanly when a port is absent).
The `drive-zee-app` skill (`.agents/skills/drive-zee-app/SKILL.md`) is the operational
cheatsheet; this table is the contract.

| Extension | Surface | Params | Returns | Notes |
|---|---|---|---|---|
| `ext.zee.whoami` | both | _(none)_ | `{surface, isolate, pid, hudEnabled}` | Stable identity probe; driver builds the surface→isolateId map from this |
| `ext.zee.dumpState` | both | _(none)_ | `{surface, hudEnabled, …}` | Raw internal state; grows with the app |
| `ext.zee.readViewModel` | both | _(none)_ | derived view-state incl. `activeSlots`, `plannedSlots`, CarSignals, `systemLocale`, `usbMode`, `install` | Derived Riverpod view-state (ADR 0003) |
| `ext.zee.setConfig` | both | `hudEnabled`, `blinkerShape\|Size`, `battery\|temp\|chargingShow`, `locale`, `minimap*`, safe-area keys | `dumpState` snapshot | Write config; params arrive as `Map<String, String>`; DHU→HUD relay fires |
| `ext.zee.tapByKey` | both | `key=<ValueKey string>` | `{tapped:true, key, x, y\|mode}` or `{tapped:false, error}` | Synthetic tap via three-tier fallback (callback walk → pointer events → ancestor walk) |
| `ext.zee.shot` | both | _(none)_ | `{surface, w, h, png_b64}` | Per-isolate `RenderRepaintBoundary.toImage()` → PNG → base64 |
| `ext.zee.inject` | dhu | `kind=speed\|blinker\|charge\|battery\|powerFlow value=…` | CarSignals snapshot | DHU only — HUD CarSignals are relay-driven; injecting on HUD would diverge the surfaces. T2/T3 use ADB broadcast |
| `ext.zee.bootState` | both | _(none)_ | `{surface, hudEnabled, configReadOk, …native FGS fields}` | DHU/Android adds native foreground-service status; T1/HUD is config-store only |
| `ext.zee.minimap` | dhu | `on=true\|false`, `x y w h`, `key value` | `{surface, minimap, on}` | Registered only when `MinimapHost` is injected |
| `ext.zee.install` | dhu | `target=launcher\|ynavi` or `repo branch path` | `{surface, install:{target, started}}` | Registered only when `Installer` is injected; poll `readViewModel.install.phase` for progress |
| `ext.zee.setLanguage` | dhu | `scope=app\|system\|cluster value=en\|ru\|system` | `{ok, reason?, scope, value, systemLocale?}` | Registered only when `SystemConfig` is injected; `system\|cluster` is T3-only |
| `ext.zee.setUsbMode` | dhu | `value=peripheral\|host\|auto` | `{ok, reason?, usbMode, usbWritable}` | Registered only when `UsbModePort` is injected; T2 needs platform signing |

All extensions must be registered in the isolate's entrypoint **after**
`WidgetsFlutterBinding.ensureInitialized()`.  Extensions are stripped from
release builds (`kDebugMode` context); the Feedback Loop targets debug/profile
builds only.

---

## Two-channel routing table per tier

| Op | T1 (Linux desktop) | T2 (Android emulator) | T3 (car) |
|---|---|---|---|
| `whoami_all` | VM service | VM service | VM service |
| `dump_state(surface)` | VM service | VM service | VM service |
| `read_view_model(surface)` | VM service | VM service | VM service |
| `set_config(surface, …)` | VM service | VM service | VM service |
| `tap(surface, key)` | VM service | VM service | VM service |
| `shot(surface)` | VM service | VM service | VM service |
| `inject(…)` | **T1NativeStub** (raises) | Broadcast → native service | Real AdaptAPI |

The VM-service channel is **uniform across all three tiers** (verified
PoC-proven on Linux desktop and Android).  The native channel's injection
point descends the stack as the tier rises — that descent is the fidelity
gradient (ADR 0004).

---

## Surface resolution rule

Both isolates are named `main` and share a `rootLib` URI.  Surfaces are
**not** name-distinguishable.  The driver resolves surfaces by:

1. Calling `ext.zee.whoami` on each isolate returned by `getVM`.
2. Matching the `surface` field (`"dhu"` or `"hud"`).
3. Caching the resulting `surface → isolateId` map for the session.
4. Polling `getVM` until **both** surfaces answer before dispatching any
   surface-targeted op (the HUD engine starts after DHU's first frame —
   ADR 0004 §21).

`FeedbackLoop.connect()` in `dev/feedback_loop.py` implements this protocol.

---

## `ext.zee.whoami` shape

```json
{
  "surface": "dhu",
  "isolate": 1234567890,
  "pid": 98765,
  "hudEnabled": false
}
```

`isolate` is `identityHashCode(store)` — a stable discriminator for the
lifetime of the isolate.

---

## `ext.zee.tapByKey` notes

- The widget must carry a `ValueKey<String>` exactly matching the `key` param.
- The shape segments in `lib/screens/hud_settings_screen.dart` carry
  `ValueKey('blinker-shape-dots'|'blinker-shape-arrows'|'blinker-shape-smiley')`.
- Tap verification: call `dump_state(surface='hud')` after the tap and confirm
  `blinker.shape` has flipped (the DHU→HUD relay path, ADR 0003).

---

## Native channel — CarSignals injection & dump (T2/T3)

The native ADB/broadcast channel (ADR 0004). On **T1** signal injection goes over
the VM-service `ext.zee.inject` into the Dart `FakeCarSignals`; on **T2/T3** it
descends to the real native source via ordered ADB broadcasts.

**Inject** — `com.zeepowertoys.SIMULATE` (must target the component explicitly;
Android 8+ drops implicit background broadcasts):

```bash
adb shell am broadcast \
  -n com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver \
  -a com.zeepowertoys.SIMULATE --es kind <kind> --es value <value>
```

| `kind` | `value` | example |
|---|---|---|
| `speed` | int km/h | `80` |
| `blinker` | `left\|right\|hazard\|off` | `left` |
| `charge` | `<bool>:<volts>:<amps>:<kw>` | `true:760.0:55.0:42.0` |
| `battery` | `<pct>:<tempC>` | `80:27.5` |
| `powerFlow` | `drive\|regen\|standstill\|unknown` | `drive` |

**Dump** — `com.zeepowertoys.DUMP` (ordered broadcast; JSON returned in the result data):

```bash
adb shell am broadcast -n com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver \
  -a com.zeepowertoys.DUMP
# → result=0, data="{"speedKmh":80,"blinker":"left","charging":true,...}"
```

**Source override** — `setprop persist.zee.carsignals sim|adapt` (empty = auto-detect:
real AdaptAPI on the car, simulator on the emulator). `dev/feedback_loop.py --tier t2`
uses this channel for `inject`; whoami/dumpState/readViewModel/tap/shot stay on VM-service.

---

## References

- ADR 0004: `docs/adr/0004-dual-channel-feedback-loop.md`
- ADR 0003: `docs/adr/0003-*.md` (derived view-state, relay)
- Client implementation: `dev/feedback_loop.py`
- Low-level VM layer: `dev/zee_drive.py`
- Flutter-debug skill: `docs/knowledge/flutter-debug-skill-vm-service.md`
