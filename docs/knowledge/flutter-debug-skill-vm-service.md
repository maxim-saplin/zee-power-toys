# Knowledge: flutter-debug-skill-vm-service

## Flutter Debug Skill — VM-Service Channel: Complete Technical Reference

### Source Files Studied

| File | Role |
|---|---|
| `/home/user/src/nothingness/.agents/skills/agent-emulator-debugging/SKILL.md` | Operational entry point, command surface, hazards |
| `/home/user/src/nothingness/.agents/skills/agent-emulator-debugging/scripts/drive.py` | Full Python driver implementation |
| `/home/user/src/nothingness/docs/agent-driven-debugging.md` | Architecture + extension reference |
| `/home/user/src/nothingness/.agents/skills/flutter-commands/SKILL.md` | Flutter CLI permission notes |
| `/home/user/src/nothingness/dev/agent_service.dart` | Dart-side extension registration |
| `/home/user/src/nothingness/lib/debug_hooks.dart` | Thin seam between app and harness |
| `/home/user/src/nothingness/dev/main_debug.dart` | Debug entrypoint |
| `/home/user/src/zee-power-toys/_poc/feedback_loop/zee_drive.py` | PoC zee client — seed of real Feedback Loop client |
| `/home/user/src/zee-power-toys/_poc/desktop_twoengine/drive/zee_drive.py` | Desktop two-engine variant |
| `/home/user/src/zee-power-toys/_poc/desktop_twoengine/drive/probe.py` | Two-engine proof harness |
| `/home/user/src/zee-power-toys/_poc/desktop_twoengine/drive/grab_shots.py` | Per-isolate screenshot via VM service |
| `/home/user/src/zee-power-toys/_poc/multidisplay_poc/lib/main.dart` | Android two-engine ext.zee.* registration |
| `/home/user/src/zee-power-toys/_poc/desktop_twoengine/lib/main.dart` | Desktop two-engine ext.zee.* + shot |

---

## 1. Architecture Overview

```
Agent/Script (Python CLI, drive.py / zee_drive.py)
  |
  | WebSocket JSON-RPC 2.0
  v
Dart VM Service  ws://127.0.0.1:<port>/<auth_token>/ws
  |
  | getVM -> isolates[]  (one VM, multiple isolates in two-engine setup)
  | getIsolate -> extensionRPCs[]
  | callServiceExtension (ext.<ns>.<method> + isolateId)
  v
AgentService / ext.nothingness.*   (nothingness)
ext.zee.*                          (zee-power-toys)
  |
  v
App internals: SettingsService, PlaybackController, LibraryController, etc.
```

The VM service is a **single endpoint** that can see ALL isolates — confirmed PoC-proven in both Android (`FlutterEngineGroup`) and Linux desktop (`desktop_multi_window`) two-engine setups.

---

## 2. VM Service URI Discovery

### Linux/macOS Desktop (`flutter run -d linux`)

Flutter automatically forwards a host-local URI to `/tmp/flutter_run.log` (or `$DRIVE_RUN_LOG`). No adb needed.

`drive.py:_scan_flutter_run_log_for_vm_uri()` (`drive.py:233-247`) reads the log file and scans with these three regex patterns (`drive.py:178-185`):

```python
VM_PATTERNS = [
    re.compile(r"Dart VM service.*?listening on (http://[^\s/]+/[A-Za-z0-9_=\-]+/?)"),
    re.compile(r"Observatory.*?listening on (http://[^\s/]+/[A-Za-z0-9_=\-]+/?)"),
    re.compile(r"A Dart VM Service .*?:\s+(http://[^\s/]+/[A-Za-z0-9_=\-]+/?)")
]
```

All three patterns target the log line:
`A Dart VM Service on <device> is available at: http://127.0.0.1:<PORT>/<TOKEN>=/`

### Android (emulator / device)

Two paths, in priority order (`drive.py:250-293` `_resolve_ws`):
1. **flutter run log** — `flutter run` forwards a host-local URI automatically; parse from log file. Same as desktop, no adb forward needed when using `flutter run`.
2. **logcat scan** — `_scan_logcat_for_vm_uri()` (`drive.py:202-212`): `adb logcat -d -v brief -t 5000`, same three regex patterns. Then `_parse_vm_uri()` extracts `(remote_port, token)` and `_forward_port()` calls `adb forward tcp:8181 tcp:<remote_port>`.

URI normalization (`drive.py:188-199` `_normalize_ws_uri`): converts `http://` to `ws://` and appends `/ws` if needed, producing `ws://127.0.0.1:<port>/<token>/ws`.

### URI Caching

Cache file at `/tmp/drive_vm_ws.txt` (or `$DRIVE_WS_CACHE`, defaulted by `_default_ws_cache()` based on run-log path hash). The log is always scanned first as it is authoritative for the current session; the cache is only read when the log has no URI. (`drive.py:256-293`)

### zee_drive.py Discovery (PoC)

`_poc/feedback_loop/zee_drive.py:111-127` `resolve_ws_uri()`: same three patterns, logcat scan only (no flutter run log path), with override via `--vm-uri` arg or `$ZEE_VM_URI`. Same `adb forward` pattern. Env: `ADB_SERIAL` (default `emulator-5554`), `ZEE_LOCAL_PORT` (default `8181`), `ZEE_RPC_TIMEOUT` (default `30`s).

---

## 3. Enumerating Isolates — `getVM`

```python
vm = call(ws_uri, "getVM", {})
isolates = vm.get("isolates", [])  # list of {id, name, number, ...}
```

Each element in `isolates[]` has at minimum: `id` (string, e.g. `"isolates/1234"`), `name` (string), `number` (int).

For the nothingness single-engine case there is one isolate. For the two-engine case (zee-power-toys) there are two, **both named `"main"`** — this is the critical nuance.

---

## 4. The Two-Isolate "Both Named Main" Problem and `whoami` Resolution

**ADR 0004 (`/home/user/src/zee-power-toys/docs/adr/0004-dual-channel-feedback-loop.md`) states explicitly:**

> Two nuances the loop must honour: (1) the HUD engine must be created and running for its isolate to exist — poll `getVM` until both surfaces resolve rather than assuming both are up at connect; (2) both isolates are named `main` and share a `rootLib`, so surfaces are not name-distinguishable — every driveable surface must expose a `whoami`-style probe and the driver builds the surface→isolateId map from it.

### The `whoami` Pattern

In `_poc/feedback_loop/zee_drive.py:157-188` `VMClient.resolve_isolate()`:

```python
if selector in ("primary", "hud"):            # surface match via whoami
    for iso in isos:
        try:
            res = await self.rpc("ext.zee.whoami", {"isolateId": iso["id"]})
        except Exception:
            continue
        if isinstance(res, dict) and res.get("surface") == selector:
            return iso["id"]
```

`ext.zee.whoami` returns `{"surface": "primary"|"hud", "isolate": identityHashCode, "tick": N, ...}` — registered separately in each isolate's entrypoint with its own surface string.

In `_poc/multidisplay_poc/lib/main.dart:56-72` (`_registerZeeExtensions(String surface)`):
```dart
developer.registerExtension('ext.zee.whoami', (String method, Map<String, String> parameters) async {
  return developer.ServiceExtensionResponse.result(_zeeReport(surface));
});
```

Called with `_registerZeeExtensions('primary')` in `main()` and `_registerZeeExtensions('hud')` in `@pragma('vm:entry-point') void hudMain()`.

Desktop variant (`_poc/desktop_twoengine/lib/main.dart:70-110`) includes `pid`, `window`, `counter`, `configFromMain` in the report. The `identityHashCode(counter)` (i.e., identity hash of a top-level isolate-local ValueNotifier) serves as the stable isolate discriminator.

### `_registered_extensions` — Live Contract Discovery

`drive.py:861-884`:
```python
def _registered_extensions(ws: str) -> list[str]:
    vm = call(ws, "getVM", {})
    isolates = vm.get("isolates", [])
    # Prefer the 'main' isolate; fall back to the first.
    main = next((i for i in isolates if i.get("name") == "main"), isolates[0])
    iso = call(ws, "getIsolate", {"isolateId": main.get("id")})
    rpcs = iso.get("extensionRPCs")
    ...
    return sorted(r for r in rpcs if isinstance(r, str) and r.startswith("ext.nothingness."))
```

`getIsolate` RPC returns a full isolate object including `extensionRPCs: []` — the live list of registered extension names for that isolate. Never hardcode the count; always query at runtime.

**For zee-power-toys**: the equivalent should filter for `ext.zee.*` instead of `ext.nothingness.*`.

---

## 5. Calling Service Extensions (`callServiceExtension` / ext.* RPC)

The VM service protocol treats custom extensions as first-class method names (NOT a nested `callServiceExtension` method). The method name IS the extension name:

```python
# JSON-RPC payload
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "ext.nothingness.getPlaybackState",
  "params": {"isolateId": "isolates/1234"}
}
```

Response envelope (`docs/agent-driven-debugging.md:199-209`):
```json
{"jsonrpc": "2.0", "result": {...}, "id": 1}
{"jsonrpc": "2.0", "error": {"code": -32000, "message": "...", "data": {"details": "..."}}, "id": 1}
```

Core async call implementation (`drive.py:303-329`):
```python
async def _call_async(ws_uri: str, method: str, params: dict) -> Any:
    async with websockets.connect(ws_uri, max_size=8 * 1024 * 1024) as ws:
        await ws.send(json.dumps(payload))
        while True:
            raw = await asyncio.wait_for(ws.recv(), timeout=30)
            msg = json.loads(raw)
            if msg.get("id") == req_id:
                if "error" in msg:
                    raise RuntimeError(json.dumps(msg["error"]))
                return msg.get("result")
```

Note: `max_size=8 * 1024 * 1024` for normal extension calls; `_RAW_MAX_SIZE = 64 * 1024 * 1024` for raw VM RPCs like `getCpuSamples`, `getVMTimeline` (`drive.py:367`).

The `_ext()` function (`drive.py:332-344`) automatically resolves the first isolate and injects `isolateId`. For zee-power-toys, isolate resolution must use `whoami` instead of taking `isolates[0]`.

### Resilience Pattern

`_ext_resilient()` (`drive.py:347-362`): on transport failure, deletes the WS cache and retries once with `force=True` rediscovery. This handles the common case where the cached URI points at a dead session.

---

## 6. Dart-Side Extension Registration (`developer.registerExtension`)

`dev/agent_service.dart:114-122`:
```dart
static void _registerExtensions() {
  _extensions.forEach((name, handler) {
    developer.registerExtension('ext.nothingness.$name', handler);
  });
  debugPrint('[AgentService] registered ${_extensions.length} VM service extensions');
}
```

Handler signature: `Future<developer.ServiceExtensionResponse> Function(String method, Map<String, String> params)`.

Response constructors:
- `developer.ServiceExtensionResponse.result(jsonEncode(data))` — success
- `developer.ServiceExtensionResponse.error(developer.ServiceExtensionResponse.extensionError, message)` — error

**All params arrive as `Map<String, String>`** — everything is a string on the wire; handlers must parse ints, booleans, doubles manually.

The `_extensions` map at `agent_service.dart:61-98` is the authoritative list; `drive.py contract` reads it live from `extensionRPCs`.

### Extension Installation Lifecycle

`agent_service.dart:104-112` `AgentService.install()`:
1. Guards on `kDebugMode` and `_installed` (idempotent).
2. Installs `_installOverflowHook()` immediately — captures `FlutterError.onError`.
3. Sets `DebugHooks.onAppReady = (_) { _registerExtensions(); _installFrameHook(); }` — deferred to app init completion.

`lib/debug_hooks.dart:22` `onAppReady`: called by the app once init completes; the harness fires then. **Extensions are NOT available until after `onAppReady` fires.**

For zee-power-toys, the equivalent pattern is: call `_registerZeeExtensions('primary')` / `_registerZeeExtensions('hud')` inside each engine's entrypoint (`main()` and `hudMain()`) after `WidgetsFlutterBinding.ensureInitialized()`.

---

## 7. Screenshot Capture

### Desktop (Linux/macOS) — VM service path

`agent_service.dart:1150-1172` `_screenshot()`:
```dart
final renderObject = DebugHooks.screenshotBoundaryKey.currentContext?.findRenderObject();
if (renderObject is! RenderRepaintBoundary) return _error('screenshot boundary not mounted yet');
final image = await renderObject.toImage(pixelRatio: pixelRatio);
final png = await image.toByteData(format: ui.ImageByteFormat.png);
return _ok({'png_base64': base64Encode(png.buffer.asUint8List()), 'width': width, 'height': height});
```

Requires a `RepaintBoundary(key: DebugHooks.screenshotBoundaryKey)` widget in the tree. Returns `{png_base64: "...", width: N, height: N}`.

`drive.py:600-615` `cmd_shoot()` on IS_DESKTOP: calls `ext.nothingness.screenshot`, decodes `png_base64`, writes PNG to `.tmp/agent_shots/<name>.png`. Optional `--pixel-ratio` param.

Desktop two-engine variant (`desktop_twoengine/lib/main.dart:87-107`) uses `ext.zee.shot` — same `RenderRepaintBoundary.toImage()` pattern, returns `{surface, w, h, png_b64}`. `grab_shots.py` iterates all isolates and saves `shots/<surface>.png` per isolate.

### Android — `adb exec-out screencap -p`

`drive.py:619-634` `cmd_shoot()` on Android:
```python
proc = subprocess.run(["adb", "-s", DEFAULT_SERIAL, "exec-out", "screencap", "-p"], ...)
out.write_bytes(proc.stdout)
```
Falls back to `adb shell screencap -p /sdcard/<name>.png` + pull + rm on platforms where `exec-out` is flaky.

---

## 8. Gesture / Tap Driving

### `tapByKey` — by `ValueKey<String>`

`agent_service.dart:403-435` `_tapByKey()`:
Three-tier fallback:
1. **Descendant-callback walk** (`_invokeOnTapInSubtree`) — finds `GestureDetector.onTap` / `InkResponse.onTap` in the subtree of the keyed element. Returns `{mode: 'descendant-callback'}`.
2. **Synthetic pointer events** (`_dispatchSyntheticTap`) — `PointerAdded` + `PointerDown` + `PointerUp` + `PointerRemoved` at the `RenderBox` center via `GestureBinding.instance.handlePointerEvent()`. Returns `{mode: 'synthetic', at: {x, y}}`.
3. **Ancestor walk** (`_invokeOnTapAncestor`) — climbs the element tree looking for a tappable ancestor. Returns `{mode: 'ancestor-callback'}`.

`_findElementByKey()` (`agent_service.dart:204-217`): depth-first pre-order walk from `WidgetsBinding.instance.rootElement`, matches `el.widget.key == ValueKey<String>(key)`.

Synthetic pointer ID scheme (`agent_service.dart:345-346`): `_syntheticPointerSeq++; pointer = 0x70000 | (_syntheticPointerSeq & 0xFFFF)` — monotonically-increasing to avoid gesture arena collisions.

### `dragByKey` — horizontal / vertical drag

`agent_service.dart:437-556` `_dragByKey()`. Params: `key`, `dx`, `dy`, `steps` (default 8, clamped 1-120), `kind` (`touch`/`mouse`; auto-defaults by platform).

Two-tier:
1. **Direct `GestureDetector` callback injection** (`_invokeDragInSubtree`): calls `onHorizontalDragStart/Update/End` or `onVerticalDragStart/Update/End` directly. Deterministic, avoids platform recognizer issues.
2. **Synthetic pointer events**: `PointerAdded` + `PointerDown` + N x `PointerMove` (spaced 8ms apart) + `PointerUp` + `PointerRemoved`.

### adb-based (Android)

For gesture-dependent UI (velocity-gated hero swipes, `PageView` flings) that don't have semantic equivalents: `adb shell input swipe <x1> <y1> <x2> <y2> [duration_ms]`. **Hazard**: ADB swipe cadence is fixed; velocity computed by Flutter is far below a real flick. Never use for fling/dismiss; prefer widget tests for those.

---

## 9. Reading the Dart View-Model

The key extensions for reading VM state (`docs/agent-driven-debugging.md`):

| Extension | Returns | Used For |
|---|---|---|
| `ext.nothingness.getPlaybackState` | `{isPlaying, currentIndex, shuffle, queueLength, queue[], songInfo, spectrumNonZero}` | playback state |
| `ext.nothingness.getRouterState` | `{screen, themeVariant, operatingMode, immersive, fullScreen}` | active screen / shell config |
| `ext.nothingness.getLibraryState` | `{currentPath, folders[], tracks[], smartRoots[], hasPermission, isLoading}` | file browser state |
| `ext.nothingness.getSettings` | full settings JSON | all SettingsService fields |
| `ext.nothingness.getWidgetTree` | `{tree: "..."}` | widget hierarchy as text |
| `ext.nothingness.probeText` | `{text, style:{fontSize, color(ARGB hex), fontWeight, fontFamily, height, letterSpacing}, widgetType, size}` | live rendered text + TextStyle from `RenderParagraph` |

`probeText` (`agent_service.dart:1066-1111`) walks the element tree to the keyed widget's `RenderParagraph` and returns `para.text.toPlainText()` + `para.text.style` (fully resolved, what was actually painted).

For zee-power-toys, equivalent extensions should be named `ext.zee.*` and return the relevant view-model fields per surface.

---

## 10. Python Library Structure (for Porting)

The nothingness `drive.py` is structured as a reusable module with these layers:

### Layer 1 — URI Discovery (pure functions)
```
_scan_flutter_run_log_for_vm_uri() -> str | None   # scans log file
_scan_logcat_for_vm_uri(serial, max_lines) -> str | None   # scans adb logcat
_parse_vm_uri(uri) -> (port, token)
_forward_port(remote_port, serial) -> local_port
_normalize_ws_uri(uri) -> ws://... normalized
_resolve_ws(serial, force) -> ws_uri   # full resolution with cache
```

### Layer 2 — JSON-RPC over WebSocket
```python
async def _call_async(ws_uri, method, params) -> Any:
    async with websockets.connect(ws_uri, max_size=8*1024*1024) as ws:
        await ws.send(json.dumps(payload))
        while True:
            msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=30))
            if msg.get("id") == req_id: return msg.get("result")

def call(ws_uri, method, params) -> Any:
    return asyncio.run(_call_async(...))  # sync wrapper
```

### Layer 3 — Isolate Resolution
```python
def _ext(ws_uri, ext_method, params) -> Any:
    vm = call(ws_uri, "getVM", {})
    isolate_id = vm.get("isolates", [])[0].get("id")  # first isolate
    full_params = dict(params or {})
    full_params.setdefault("isolateId", isolate_id)
    return call(ws_uri, ext_method, full_params)
```

**For zee-power-toys, this must be replaced with `whoami`-based surface→isolateId mapping** (see `zee_drive.py VMClient.resolve_isolate()`).

### Layer 4 — Resilience Wrapper
```python
def _ext_resilient(ext_method, params, serial, _retried=False) -> Any:
    try:
        ws = _resolve_ws(serial=serial)
        return _ext(ws, ext_method, params)
    except Exception:
        if _retried: raise
        WS_CACHE.unlink(missing_ok=True)
        _resolve_ws(serial=serial, force=True)
        return _ext_resilient(ext_method, params, serial=serial, _retried=True)
```

### Layer 5 — Subcommands (one function per semantic op)

Each `cmd_*` function takes `args` (parsed argparse namespace), calls `_ext_resilient(...)`, prints JSON. Entry point is `main(argv)` via `build_parser()`.

### zee_drive.py `VMClient` Class (cleaner OOP alternative)

`_poc/feedback_loop/zee_drive.py:133-188` shows the cleaner pattern for zee-power-toys:
- `VMClient(ws)` — thin wrapper around a persistent WebSocket connection
- `await c.rpc(method, params)` — sends one JSON-RPC and awaits the matching response
- `await c.isolates()` — `getVM -> isolates[]`
- `await c.resolve_isolate(selector)` — `None` → first; `"primary"`/`"hud"` → `whoami` probe

`_with_client(ws_uri, fn)` creates the connection and passes `VMClient` to `fn`:
```python
async def _with_client(ws_uri, fn):
    async with websockets.connect(ws_uri, max_size=8*1024*1024) as ws:
        return await fn(VMClient(ws))
```

This persistent-connection pattern is more efficient than `drive.py`'s per-call open/close for multi-step probes.

---

## 11. Breakpoint / Advanced VM Inspection

`drive.py:1105-1223` `_breakpoint_session()`:
1. `getVM` → `iso` (isolates[0].id)
2. `streamListen {"streamId": "Debug"}` — subscribe to pause events
3. `addBreakpointWithScriptUri {"isolateId": iso, "scriptUri": args.uri, "line": args.line}`
4. Fire trigger (e.g. `ext.nothingness.next`) on a SEPARATE connection (fire-and-forget; the isolate pauses mid-RPC so the trigger's reply never arrives)
5. Pump the session socket until `streamNotify` with `event.kind == "PauseBreakpoint"`
6. `getStack {"isolateId": iso}` → `frames[:8]`
7. `evaluateInFrame {"isolateId": iso, "frameIndex": 0, "expression": expr}` per `--watch`
8. `finally`: `removeBreakpoint`, `resume` — **never orphan a paused isolate**

Critical hazard: `breakpoint` pauses the UI isolate, freezing ALL `ext.zee.*` extensions on that isolate. Run alone.

Raw VM RPCs for profiling:
- `setVMTimelineFlags {"recordedStreams": ["Dart", "Embedder", "GC"]}` + `clearVMTimeline` — arm timeline
- `getVMTimeline` — fetch recorded spans; `traceEvents[].{name, dur, args}`
- `getCpuSamples {"timeOriginMicros": t0, "timeExtentMicros": extent, "isolateId": iso}` — CPU profile; max frame 64 MB; `samples[].stack` is leaf-first

Note: `getVMTimestamp` is unavailable on this VM; time origin derived from `getVMTimeline.timeOriginMicros + timeExtentMicros`.

---

## 12. Hot Reload / Restart via FIFO

Desktop only. A named FIFO at `/tmp/flutter_input` (or `$DRIVE_FLUTTER_FIFO`) is kept open by a `sleep infinity` process, which also holds `flutter run`'s stdin open. Writing `r\n` triggers hot reload, `R\n` triggers hot restart (`drive.py:686-735`).

After hot restart, the VM URI may change and extensions re-register; `WS_CACHE.unlink()` on restart (`drive.py:733`).

---

## 13. Platform Differences: Linux Desktop vs Android

| Concern | Linux desktop | Android |
|---|---|---|
| VM URI source | `flutter run` log (host-local) | `flutter run` log (forwarded) OR logcat + `adb forward` |
| Screenshot | `ext.nothingness.screenshot` (`RenderRepaintBoundary.toImage`) | `adb exec-out screencap -p` |
| Logcat | Tail `$DRIVE_RUN_LOG` | `adb logcat -d -v brief -t N` |
| Hot reload/restart | FIFO (`r`/`R` to `flutter run` stdin) | FIFO (same mechanism) |
| Permission grants | No-op | `pm grant <pkg> android.permission.*` |
| App data reset | Kill + relaunch `flutter run` | `adb shell pm clear <pkg>` (NEVER with live flutter run) |
| Frame timings | `addTimingsCallback` fires only for on-screen compositor frames; `count=0` for background-only activity | Reliable; primary jank lens |
| ADB dependency | None | Required for logcat scan + screencap + pm grant |

---

## 14. Environment Variables (for configuration in zee-power-toys port)

| Variable | Default | Meaning |
|---|---|---|
| `DRIVE_TARGET` | auto-sniff | `android`/`linux`/`macos` |
| `DRIVE_RUN_LOG` | `/tmp/flutter_run.log` | `flutter run` stdout path |
| `DRIVE_WS_CACHE` | `/tmp/drive_vm_ws.txt` | cached WebSocket URI |
| `DRIVE_FLUTTER_FIFO` | `/tmp/flutter_input` | FIFO for hot reload/restart |
| `DRIVE_DESKTOP_HOME` | `/tmp/nothingness_<hash>` | isolated HOME for desktop session |
| `DRIVE_LOCAL_PORT` | `8181` | local port for adb forward |
| `ADB_SERIAL` | `emulator-5554` | adb device serial |
| `ZEE_VM_URI` | — | override VM service URI (zee variant) |
| `ZEE_LOCAL_PORT` | `8181` | local port (zee variant) |
| `ZEE_RPC_TIMEOUT` | `30` | RPC timeout in seconds (zee variant) |

---

## 15. Hazards and Rate Limits

- **Cadence ≤5/s** for mutating RPCs (each costs ~140ms on emulator). >7/s causes response queue backup that looks like a wedged isolate. Recovery: `rm $DRIVE_WS_CACHE && drive.py restart`.
- **Never kill the live `flutter run`** (`adb shell am force-stop`, `pm clear`, `pm revoke`) while it's attached — causes `Lost connection to device` + 60-90s rebuild.
- **Velocity-gated gestures** (flings, swipes) cannot be reliably driven via adb input or synthetic pointer events; use widget tests with `tester.fling()`.
- **Breakpoint pauses ALL extensions** on the affected isolate — run alone, always resume in `finally`.
- **WSL2 hot reload**: file watcher (inotify) doesn't fire reliably on WSL2; kill and relaunch `flutter run` on code changes. Hot reload works on native Linux/macOS.
- **Two-engine startup race**: poll `getVM` until both isolates exist + both return `ext.zee.whoami` without error before dispatching surface-specific calls.
- **`frames` empty on headless Linux**: `addTimingsCallback` only fires for on-screen compositor frames.

---

## 16. Dart Extension Registration Pattern for zee-power-toys

Each Flutter engine/isolate calls `developer.registerExtension(name, handler)` in its entrypoint, **after** `WidgetsFlutterBinding.ensureInitialized()`.

```dart
import 'dart:developer' as developer;

void _registerZeeExtensions(String surface) {
  developer.registerExtension('ext.zee.whoami', (m, p) async {
    return developer.ServiceExtensionResponse.result(jsonEncode({
      'surface': surface,
      'isolate': identityHashCode(someIsolateScopedObject),
      'pid': pid,   // from dart:io
      // add view-model fields here
    }));
  });
  developer.registerExtension('ext.zee.dumpState', (m, p) async {
    // read view-model, return JSON
    return developer.ServiceExtensionResponse.result(jsonEncode({...}));
  });
  developer.registerExtension('ext.zee.setConfig', (m, p) async {
    // write config; params are Map<String, String>
    return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true}));
  });
  // etc.
}
```

The seam pattern (`DebugHooks`) is optional for zee-power-toys since extensions are registered directly in the entrypoint. The `AgentService` class with its `_extensions` map + `install()` + `DebugHooks.onAppReady` lifecycle is the nothingness-specific elaboration of the same underlying `developer.registerExtension` primitive.

For the `ext.zee.screenshot` extension: the `RenderRepaintBoundary.toImage()` approach from `desktop_twoengine/lib/main.dart:87-107` is confirmed working under WSLg where no system window-grab tool exists.

## Lift-ready artifacts

### zee_drive.py (feedback_loop variant)
- **Source:** `/home/user/src/zee-power-toys/_poc/feedback_loop/zee_drive.py`
- **What:** Minimal production-seed Feedback Loop client: VM URI discovery (logcat + adb forward + $ZEE_VM_URI override), VMClient class with persistent WebSocket, resolve_isolate() with whoami-based surface mapping, generic call subcommand. PEP 723 inline deps (websockets>=12.0), runs with `uv run --script`.
- **Reuse:** Port directly as the VM-service channel client for zee-power-toys. Replace ext.nothingness.* references with ext.zee.*. Add subcommands for dumpState, setConfig, tap, readViewModel. Expand resolve_isolate() selector set as needed. This is the cleanest starting point — already adapted for zee namespace and two-isolate topology.

### VMClient class
- **Source:** `/home/user/src/zee-power-toys/_poc/feedback_loop/zee_drive.py`
- **What:** Python class (lines 133-193) wrapping a single persistent WebSocket with `rpc(method, params)`, `isolates()` (getVM), and `resolve_isolate(selector)` that dispatches ext.zee.whoami to map 'primary'/'hud' selectors to isolateIds.
- **Reuse:** Use as the base class for the full Feedback Loop client. The `resolve_isolate()` method with whoami-fallback is the critical two-engine pattern — do NOT simplify to `isolates[0]`.

### drive.py _resolve_ws / VM URI discovery stack
- **Source:** `/home/user/src/nothingness/.agents/skills/agent-emulator-debugging/scripts/drive.py`
- **What:** Lines 178-293: VM_PATTERNS (3 regexes), _normalize_ws_uri(), _scan_flutter_run_log_for_vm_uri(), _scan_logcat_for_vm_uri(), _parse_vm_uri(), _forward_port(), _resolve_ws(). Also: _default_ws_cache(), _default_flutter_fifo(), _path_tag() for session-isolated temp file naming.
- **Reuse:** Port verbatim to zee Feedback Loop client. Use all three VM_PATTERNS. Prefer flutter-run-log scan over logcat scan (works for both Linux and Android when using `flutter run`). Use the session-tag pattern for parallel desktop sessions.

### drive.py _ext_resilient / _raw_resilient
- **Source:** `/home/user/src/nothingness/.agents/skills/agent-emulator-debugging/scripts/drive.py`
- **What:** Lines 347-415: resilience wrappers that delete the WS cache and retry once on any transport error. _raw_resilient adds scoped=True to auto-inject isolateId for raw VM RPCs.
- **Reuse:** Port the cache-delete-and-retry-once pattern. For zee-power-toys, combine with the VMClient/resolve_isolate pattern to retry the full whoami-based surface mapping on reconnect.

### AgentService — Dart extension registration pattern
- **Source:** `/home/user/src/nothingness/dev/agent_service.dart`
- **What:** Complete reference implementation of developer.registerExtension() usage: handler signature (String method, Map<String, String> params) -> Future<ServiceExtensionResponse>, ServiceExtensionResponse.result(jsonEncode(data)), ServiceExtensionResponse.error(extensionError, msg), _withProvider() pattern for deferred provider access, _findElementByKey/tapByKey/dragByKey for UI driving, RenderRepaintBoundary.toImage() for screenshots, SchedulerBinding.addTimingsCallback for frame jank, FlutterError.onError hook for overflow capture.
- **Reuse:** Use as the complete Dart-side reference for ext.zee.* extension implementations. The _tapByKey three-tier fallback (callback walk -> synthetic pointer -> ancestor walk) and _dragByKey two-tier fallback are directly portable. The DebugHooks seam is optional — can register directly in entrypoints as done in the PoC.

### DebugHooks seam
- **Source:** `/home/user/src/nothingness/lib/debug_hooks.dart`
- **What:** Ultra-thin static class (22 lines) that decouples the production app from the debug harness: Object? provider, Object? libraryController, screenshotBoundaryKey, navigatorKey, settingsOpener, browserExpander, onAppReady callback. All fields are untyped (Object?) to avoid coupling lib/ to dev/.
- **Reuse:** Port the pattern: create a ZeeDebugHooks class in lib/ with static Object? fields for each injectable service (AdaptApiPort, HudViewModel, etc.). The AgentService in dev/ casts and uses them. The production entrypoint only populates them in debug builds. The onAppReady deferred registration pattern ensures extensions are up only after all services are initialized.

### ext.zee.shot (desktop screenshot via RepaintBoundary)
- **Source:** `/home/user/src/zee-power-toys/_poc/desktop_twoengine/lib/main.dart`
- **What:** Lines 87-107: `ext.zee.shot` extension using RenderRepaintBoundary.toImage(pixelRatio: 1.0) -> toByteData(format: png) -> base64Encode. Returns {surface, w, h, png_b64}. Confirmed working under WSLg where no system window-grab tool exists.
- **Reuse:** Port as ext.zee.screenshot in zee-power-toys. Each engine must have a RepaintBoundary(key: _shotKey) at its root. Rename return key from png_b64 to png_base64 to match nothingness convention (or keep consistent internally).

### grab_shots.py — per-isolate screenshot collection
- **Source:** `/home/user/src/zee-power-toys/_poc/desktop_twoengine/drive/grab_shots.py`
- **What:** 44-line script that iterates all isolates, calls ext.zee.shot on each, decodes base64, saves shots/<surface>.png. Uses zee_drive.py as a library.
- **Reuse:** Port as a zee_drive.py subcommand: `shoot <name>` that dispatches to ext.zee.screenshot on the appropriate isolate (by surface selector) or captures both and names them <name>_primary.png / <name>_hud.png.

### probe.py — two-engine proof harness
- **Source:** `/home/user/src/zee-power-toys/_poc/desktop_twoengine/drive/probe.py`
- **What:** 102-line script that proves: (1) getVM sees both isolates, (2) whoami maps surface->isolateId, (3) independent memory (bump HUD, PRIMARY unchanged), (4) cross-window sync via Hub channel. Uses zee_drive.py as a library.
- **Reuse:** Port as the baseline integration test / CI smoke test for the Feedback Loop client. Run it at T1 (desktop) to verify the dual-isolate channel works before moving to T2 (Android emulator).

### _poc/multidisplay_poc/lib/main.dart — Android two-engine ext.zee.* pattern
- **Source:** `/home/user/src/zee-power-toys/_poc/multidisplay_poc/lib/main.dart`
- **What:** Complete Android FlutterEngineGroup two-engine pattern: main() registers ext.zee.whoami + ext.zee.bump with surface='primary'; @pragma('vm:entry-point') hudMain() registers same extensions with surface='hud'. Both use identityHashCode(tick) as isolate discriminator.
- **Reuse:** Use as the template for the production Android entrypoints in zee-power-toys. The @pragma('vm:entry-point') annotation on hudMain() is required for the Android runtime to find and call it from the FlutterEngineGroup host. The ext.zee.whoami extension shape (surface, isolate, pid) is the established contract — do not change field names.


## Concrete API surface

- developer.registerExtension(String name, ServiceExtensionHandler handler)
- developer.ServiceExtensionResponse.result(String encodedJson)
- developer.ServiceExtensionResponse.error(int code, String message)
- developer.ServiceExtensionResponse.extensionError (int constant = -32000)
- developer.Timeline.startSync(String label, {Map<String, Object?> arguments})
- developer.Timeline.finishSync()
- ext.zee.whoami -> {surface, isolate: identityHashCode, tick/counter, pid, [configFromMain, window]}
- ext.zee.bump -> {surface, isolate, counter} (increments isolate-local counter)
- ext.zee.pushConfig -> {surface, pushed, hub} (PRIMARY->HUD via native Hub channel)
- ext.zee.shot -> {surface, w, h, png_b64} (per-isolate RepaintBoundary screenshot)
- ext.nothingness.getPlaybackState -> {isPlaying, currentIndex, shuffle, queueLength, queue[], songInfo, spectrumNonZero}
- ext.nothingness.getRouterState -> {screen, themeVariant, operatingMode, immersive, fullScreen}
- ext.nothingness.getLibraryState -> {currentPath, folders[], tracks[], hasPermission, isLoading}
- ext.nothingness.getSettings -> full settings JSON
- ext.nothingness.setSetting name=<k> value=<v>
- ext.nothingness.setPreference key=<k> value=<v> type=bool|int|double|string|stringlist
- ext.nothingness.clearPreference key=<k>
- ext.nothingness.getWidgetTree [depth=N] -> {tree}
- ext.nothingness.getSemantics -> {semantics}
- ext.nothingness.tapByKey key=<ValueKey<String>> -> {tapped, mode}
- ext.nothingness.dragByKey key=<k> dx=<f> dy=<f> [steps=8] [kind=touch|mouse]
- ext.nothingness.probeText key=<k> -> {text, style:{fontSize, color, fontWeight, fontFamily, height, letterSpacing}, widgetType, size}
- ext.nothingness.screenshot [pixelRatio=1.0] -> {png_base64, width, height}
- ext.nothingness.getFrameTimings [clear=true] -> {count, janky16, janky33, worstBuildUs, worstRasterUs, worstTotalUs, frames[]}
- ext.nothingness.getOverflowReports [clear=true] -> {reports[], count}
- ext.nothingness.getPlaybackState, play, pause, next, prev, seek, setQueue, getDiagnostics, getAudioEvents, simulateInterruption, simulateNoisy
- ext.nothingness.navigateVoid path=<p>, navigateVoidUp, openSettingsSheet, closeSettingsSheet, playTrackByPath path=<p>
- ext.nothingness.requestLibraryPermission -> {granted}
- VM Protocol: getVM -> {isolates: [{id, name, number}]}
- VM Protocol: getIsolate {isolateId} -> {extensionRPCs: [], rootLib: {uri}}
- VM Protocol: streamListen {streamId: Debug}
- VM Protocol: addBreakpointWithScriptUri {isolateId, scriptUri, line}
- VM Protocol: removeBreakpoint {isolateId, breakpointId}
- VM Protocol: resume {isolateId}
- VM Protocol: getStack {isolateId} -> {frames: [{function, location: {script, tokenPos, line}}]}
- VM Protocol: evaluateInFrame {isolateId, frameIndex, expression} -> InstanceRef
- VM Protocol: setVMTimelineFlags {recordedStreams: [Dart, Embedder, GC]}
- VM Protocol: clearVMTimeline
- VM Protocol: getVMTimeline -> {traceEvents: [{name, dur, ts, args}], timeOriginMicros, timeExtentMicros}
- VM Protocol: getCpuSamples {isolateId, timeOriginMicros, timeExtentMicros} -> {samples[], functions[], sampleCount}
- SchedulerBinding.instance.addTimingsCallback(List<FrameTiming> timings)
- FrameTiming.buildDuration, rasterDuration, totalSpan
- RenderRepaintBoundary.toImage(pixelRatio: double) -> Future<ui.Image>
- ui.Image.toByteData(format: ui.ImageByteFormat.png) -> Future<ByteData?>
- GestureBinding.instance.handlePointerEvent(PointerEvent)
- PointerAddedEvent, PointerDownEvent, PointerUpEvent, PointerRemovedEvent, PointerMoveEvent
- WidgetsBinding.instance.rootElement -> Element?
- Element.visitChildren, visitAncestorElements, findRenderObject
- RenderBox.localToGlobal, globalToLocal, size.center
- FlutterError.onError (override for error capture)
- developer.registerExtension requires kDebugMode (stripped from release)
- DRIVE_TARGET, DRIVE_RUN_LOG, DRIVE_WS_CACHE, DRIVE_FLUTTER_FIFO, DRIVE_DESKTOP_HOME, DRIVE_LOCAL_PORT, ADB_SERIAL, DRIVE_SESSION_TAG
- ZEE_VM_URI, ZEE_LOCAL_PORT, ZEE_RPC_TIMEOUT, ADB_SERIAL
- adb logcat -d -v brief -t <N>
- adb forward tcp:<local> tcp:<remote>
- adb exec-out screencap -p
- adb shell am start -n <pkg>/<activity>
- adb shell pm grant <pkg> android.permission.<P>
- websockets.connect(ws_uri, max_size=8*1024*1024)

## Risks

- Two isolates both named 'main' — do NOT use isolate name or isolates[0] to select surfaces in zee-power-toys. MUST use ext.zee.whoami probe and match surface field. If whoami is not registered (engine still starting), all calls to that isolate's extensions will fail with 'method not found'. Poll getVM in a loop until both surfaces answer.
- HUD engine startup race: the secondary FlutterEngineGroup engine (Android) or desktop_multi_window sub-window (Linux) is created asynchronously. The primary isolate is up first; the HUD isolate may not exist yet at first getVM call. Client must poll until isolate count == 2 and both report ext.zee.whoami without error before dispatching to 'hud'.
- Extensions are absent from release builds (kDebugMode guard). The Feedback Loop only works with debug or profile builds. Ensure flutter run / flutter build apk --debug is used; am start on a release APK will show 0 extensions.
- Cold `flutter run` pays ~1.5 GB engine download on a fresh clone. Pre-warm the cache (flutter precache --linux / --android) before expecting T1 to work in CI.
- WSL2 inotify: hot reload via FIFO sends 'r' but the resident compiler may not detect source changes on WSL2 (inotify unreliable). Kill and relaunch flutter run after code edits. This affects T1 desktop iteration speed significantly.
- VM URI changes on every launch. The ws cache (/tmp/drive_vm_ws*.txt) becomes stale after a restart. The resilience pattern (delete cache + retry once) handles this, but if the cache is stale AND the log is gone (e.g. session expired), discovery fails entirely. Always pass DRIVE_RUN_LOG when running parallel sessions.
- adb forward survives across sessions on some hosts — stale forward from a previous session can point at a dead port. After killing a flutter run, clear the forward: `adb forward --remove tcp:8181`.
- getCpuSamples and getVMTimeline payloads can exceed 8 MiB. Must use max_size=64*1024*1024 for those RPCs. Using the default 8 MiB limit causes websockets.ConnectionClosed with a large-payload error.
- Breakpoint pauses the entire UI isolate — ALL ext.zee.* extensions on that isolate freeze. Never use breakpoint concurrently with any other driver. The always-resume-in-finally pattern is mandatory; orphaned paused isolates require WS cache deletion + hot restart to recover.
- Velocity-gated Flutter gestures (PageView fling, Dismissible, hero swipe) cannot be driven via adb input swipe or synthetic PointerMoveEvent — the computed velocity is below the threshold. These must be tested with flutter test using tester.fling(). Don't try to drive them via the VM service.
- Android scoped storage (API 29+): raw file paths under /storage/emulated/0/ may not be loadable if not MediaStore-indexed. Verify with `adb shell content query --uri content://media/external/audio/media --projection _data`. App-sandbox paths (/data/user/0/<pkg>/files/) bypass MediaStore.
- INSTALL_FAILED_UPDATE_INCOMPATIBLE / SHARED_USER_INCOMPATIBLE: signing or `sharedUserId` mismatch vs the installed APK. For **zee-power-toys on car**: do **not** `adb uninstall` (wipes prefs — see 0054). Rebuild release with AOSP/platform key (`useAospDebugKey=true`) matching the installed sharedUserId and retry `adb install -r`. Uninstall only on throwaway AVD lab installs where wipe is acceptable.

## Open questions

- What is the final ext.zee.* surface contract for zee-power-toys? The nothingness DebugHooks seam pattern (with onAppReady deferred registration) is likely needed because the AdaptApiPort and HudViewModel are initialized asynchronously after WidgetsFlutterBinding. Confirm where in the Flutter lifecycle ext.zee.* should be registered for the DHU engine (immediately in main() vs deferred to after AdaptApiPort first signal).
- Does the HUD engine (windshield/HUD display) get its own FlutterEngineGroup isolate on the Zeekr car, or does it share the same Dart isolate as the DHU engine via a shared Flutter renderer? ADR 0005 references FlutterEngineGroup but the PoC used both FlutterEngineGroup (Android) and desktop_multi_window (Linux T1). Confirm the exact mechanism so the ext.zee.whoami surface map is correct.
- The nothingness pattern uses `ext.nothingness.screenshot` for desktop (VM service) and `adb exec-out screencap -p` for Android. For zee-power-toys T2 (Android emulator, two displays), the HUD display (overlay/secondary) may not be capturable via `adb screencap`. Confirm whether ext.zee.screenshot via RepaintBoundary is required for T2 as well as T1.
- Rate limit for mutating RPCs on the Zeekr car (T3) is unknown. The nothingness reference shows ~140ms per call on a Snapdragon x86_64 emulator. The car's SoC may be faster or slower. The 5/s cadence limit should be tested empirically at T2 before assuming it holds at T3.
- The `drive.py preflight` command's live VM probe (`ext.nothingness.getRouterState`) is specific to nothingness. What is the equivalent health-check extension for zee-power-toys? `ext.zee.whoami` is the natural equivalent but requires isolate targeting. Should `preflight` probe each surface independently?