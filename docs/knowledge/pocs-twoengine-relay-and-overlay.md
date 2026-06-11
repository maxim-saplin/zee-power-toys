# Knowledge: pocs-twoengine-relay-and-overlay

## PoC Lift-Ready Findings: Two-Engine Relay & Overlay

### Overview

Two PoCs, two platforms. The desktop PoC (`_poc/desktop_twoengine`) proves the two-engine, native-mediated-relay topology on Linux using `desktop_multi_window 0.3.0`. The Android PoC (`_poc/multidisplay_poc`) proves it on Android using `FlutterEngineGroup` + `Presentation` + `FlutterTextureView`. Both are fully validated and ready to port into the walking skeleton.

---

## 1. Desktop Two-Engine Relay (Approach A — desktop_multi_window)

**File:** `_poc/desktop_twoengine/lib/main.dart`
**Dep:** `_poc/desktop_twoengine/pubspec.yaml` — `desktop_multi_window: ^0.3.0`

### How it works

`desktop_multi_window 0.3.0` creates each sub-window as a new `fl_view_new()` + `FlEngine` inside the **same GtkApplication / same process**, re-running `main()` with these args:

```
["multi_window", "<uuid windowId>", "<userArgs>"]
```

The `main()` function dispatches on `args.first == 'multi_window'` (line 125):

```dart
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final bool isSub = args.isNotEmpty && args.first == 'multi_window';
  if (isSub) {
    _surface = 'hud';
    _windowTag = 'sub:${args.length > 1 ? args[1] : "?"}';
    _registerZeeExtensions();
    _hub.setMethodCallHandler((call) async {
      if (call.method == 'setConfig') {
        configFromMain.value = (call.arguments as num).toInt();
      }
      return null;
    });
    runApp(const HudApp());
  } else {
    _surface = 'primary';
    _registerZeeExtensions();
    runApp(const PrimaryApp());
  }
}
```

### The Hub Channel (cross-engine relay)

The desktop "Hub" is a `WindowMethodChannel` in unidirectional mode. This is the in-process native-mediated relay (desktop analog of Android's native source-of-truth per ADR 0003/0004/0005):

```dart
const String kHubChannel = 'zee/hub';
const WindowMethodChannel _hub =
    WindowMethodChannel(kHubChannel, mode: ChannelMode.unidirectional);
```

**PRIMARY sends** (line 113):
```dart
Future<String> _pushConfigToHud(int value) async {
  try {
    await _hub.invokeMethod('setConfig', value);
    return 'ok';
  } catch (e) {
    return 'error: $e';
  }
}
```

**HUD receives** (line 132):
```dart
_hub.setMethodCallHandler((call) async {
  if (call.method == 'setConfig') {
    configFromMain.value = (call.arguments as num).toInt();
  }
  return null;
});
```

`setMethodCallHandler` is called on the HUD isolate only (subscriber). `invokeMethod('setConfig', value)` is called on the PRIMARY isolate only (publisher). Routing is done inside the native `ChannelRegistry` — no shared Dart heap.

### PRIMARY Window creation (idempotent guard)

```dart
Future<void> _createHud() async {
  if (_hud != null) return; // create the HUD window exactly once
  final WindowController c = await WindowController.create(
    const WindowConfiguration(arguments: 'hud', hiddenAtLaunch: true),
  );
  await c.show();
  _hud = c;
}
```

Called from `initState` via `addPostFrameCallback`, guarded with `if (_hud != null) return` for idempotency.

### RepaintBoundary wrapping for ext.zee.shot

Both `PrimaryApp` and `HudApp` wrap their root widget in a `RepaintBoundary` keyed with `_shotKey`:

```dart
// PrimaryApp (line 155):
home: RepaintBoundary(key: _shotKey, child: const PrimaryScreen()),
// HudApp (line 253):
home: RepaintBoundary(key: _shotKey, child: const HudScreen()),
```

The `GlobalKey _shotKey` is declared at top-level (line 49). Since each isolate has its own heap, there is no collision between the primary's key and the HUD's key.

---

## 2. ext.zee.* VM-Service Extension Registrations

Registered in both PoCs. The canonical full set (desktop) is in `_poc/desktop_twoengine/lib/main.dart:70–110`:

```dart
void _registerZeeExtensions() {
  developer.registerExtension('ext.zee.whoami', (m, p) async {
    return developer.ServiceExtensionResponse.result(_zeeReport());
  });
  developer.registerExtension('ext.zee.bump', (m, p) async {
    counter.value += 1;
    return developer.ServiceExtensionResponse.result(_zeeReport());
  });
  developer.registerExtension('ext.zee.pushConfig', (m, p) async {
    final int value = int.tryParse(p['value'] ?? '') ?? counter.value;
    final String outcome = await _pushConfigToHud(value);
    return developer.ServiceExtensionResponse.result(
        _zeeReport(<String, Object?>{'pushed': value, 'hub': outcome}));
  });
  developer.registerExtension('ext.zee.shot', (m, p) async {
    final ctx = _shotKey.currentContext;
    if (ctx == null) { /* error */ }
    final boundary = ctx.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return developer.ServiceExtensionResponse.result(jsonEncode({
      'surface': _surface,
      'w': image.width,
      'h': image.height,
      'png_b64': base64Encode(bd!.buffer.asUint8List()),
    }));
  });
}
```

The `_zeeReport()` function shape (line 58):
```dart
String _zeeReport([Map<String, Object?> extra = const {}]) =>
    jsonEncode({
      'surface': _surface,
      'isolate': identityHashCode(counter),
      'counter': counter.value,
      'configFromMain': configFromMain.value,
      'pid': pid,
      'window': _windowTag,
      'reload': 'v2-hotreload',
      ...extra,
    });
```

The Android PoC (`multidisplay_poc/lib/main.dart:56–70`) registers only `ext.zee.whoami` and `ext.zee.bump` (no `pushConfig`, no `shot`). The desktop PoC is the full set; port all four.

---

## 3. Android FlutterEngineGroup Host

**File:** `_poc/multidisplay_poc/android/app/src/main/kotlin/com/zeepowertoys/multidisplay_poc/MainActivity.kt`

This is the key file for the Android walking skeleton. One Activity (`FlutterActivity`), three experiments selectable by intent extra `--ei exp {1|2|3}`.

### Experiment dispatch (line 86):

```kotlin
when (exp) {
    1 -> setupExp1SingleEngine(primaryEngine, display)
    2 -> setupExp2EngineGroup(display)
    3 -> setupExp3Transparent(display)
}
```

### Experiment 2 — FlutterEngineGroup + secondary Presentation (lines 116–134)

This is the canonical two-isolate topology:

```kotlin
private fun setupExp2EngineGroup(display: Display) {
    val group = FlutterEngineGroup(this)
    engineGroup = group
    val entry = DartExecutor.DartEntrypoint(
        FlutterInjector.instance().flutterLoader().findAppBundlePath(), "hudMain")
    val eng = group.createAndRunEngine(this, entry)
    secondEngine = eng
    eng.lifecycleChannel.appIsResumed()

    val pres = Presentation(this, display)
    val fv = FlutterView(pres.context, FlutterSurfaceView(pres.context))
    pres.setContentView(fv)
    pres.show()
    presentation = pres
    fv.attachToFlutterEngine(eng)
}
```

Key points:
- `FlutterEngineGroup(this)` — creates the group, **not** a `FlutterEngineCache`.
- `DartExecutor.DartEntrypoint(findAppBundlePath(), "hudMain")` — the second argument is the Dart entrypoint name as a string, must match the `@pragma('vm:entry-point')` annotation on `hudMain()`.
- `eng.lifecycleChannel.appIsResumed()` — must be called or the engine stays paused.
- `FlutterView(pres.context, FlutterSurfaceView(pres.context))` — wraps a `FlutterSurfaceView` (opaque).
- `fv.attachToFlutterEngine(eng)` — the binding call.

### Experiment 3 — Transparent FlutterTextureView overlay OVER native MinimapView (lines 138–170)

This is the minimap + HUD overlay experiment:

```kotlin
private fun setupExp3Transparent(display: Display) {
    val pres = Presentation(this, display)
    val root = FrameLayout(pres.context)

    // (1) Native animated Minimap stand-in (bottom layer, opaque).
    val mm = MinimapView(pres.context)
    minimapView = mm
    root.addView(mm, FrameLayout.LayoutParams(480, 260).apply {
        leftMargin = 40; topMargin = 40
    })

    // (2) Transparent Flutter overlay (top layer) on its own engine.
    val group = FlutterEngineGroup(this)
    val entry = DartExecutor.DartEntrypoint(
        FlutterInjector.instance().flutterLoader().findAppBundlePath(), "hudMain")
    val eng = group.createAndRunEngine(this, entry)
    eng.lifecycleChannel.appIsResumed()

    val ftv = FlutterTextureView(pres.context)
    ftv.isOpaque = false  // <- THE KEY BIT for transparency compositing
    val fv = FlutterView(pres.context, ftv)
    root.addView(fv, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))

    pres.setContentView(root)
    pres.show()
    presentation = pres
    fv.attachToFlutterEngine(eng)
}
```

Critical: `ftv.isOpaque = false` is what enables the Flutter overlay to be transparent so the native `MinimapView` underneath shows through. The Flutter `Scaffold` in `HudOverlay` must also use `backgroundColor: Colors.transparent`.

### zee/minimap MethodChannel handler (lines 172–221)

Registered on the PRIMARY engine in `configureFlutterEngine()`:

```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zee/minimap")
    .setMethodCallHandler { call, result -> handleMinimap(call, result) }
```

All calls are posted to the main looper (`handler.post { ... }`) for thread-safety.

**setMinimap idempotency** (lines 182–193):
```kotlin
"setMinimap" -> {
    val enabled = call.argument<Boolean>("enabled") ?: true
    val want = if (enabled) View.VISIBLE else View.INVISIBLE
    if (v.visibility == want) {
        result.success("noop")  // idempotent: no-op if already in that state
    } else {
        v.visibility = want
        result.success("applied:$enabled")
    }
}
```

**setMinimapBounds** (lines 194–203):
```kotlin
"setMinimapBounds" -> {
    val x = call.argument<Int>("x") ?: 0
    val y = call.argument<Int>("y") ?: 0
    val w = call.argument<Int>("w") ?: 100
    val h = call.argument<Int>("h") ?: 100
    v.layoutParams = FrameLayout.LayoutParams(w, h).apply {
        leftMargin = x; topMargin = y
    }
    v.requestLayout()
    result.success("bounds:$x,$y,$w,$h")
}
```

**setMinimapParam** (lines 204–217) — only `key="hue"` is handled; others are silently `ignored`.

---

## 4. Dart HUD Entrypoint with @pragma annotation

**File:** `_poc/multidisplay_poc/lib/main.dart:220–226`

```dart
@pragma('vm:entry-point')
void hudMain() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerZeeExtensions('hud');
  _startClock('HUD');
  runApp(const HudApp());
}
```

The `@pragma('vm:entry-point')` annotation is **required** to prevent tree-shaking of the `hudMain` function when building in release/profile mode. Without it, `DartEntrypoint("hudMain")` will fail silently or crash.

### HudOverlay transparency setup (line 265):
```dart
return Scaffold(
  backgroundColor: Colors.transparent,   // must match ftv.isOpaque = false
  body: Stack(children: [ /* overlaid widgets */ ]),
);
```

---

## 5. Native MinimapView (TextureView-based)

**File:** `_poc/multidisplay_poc/android/app/src/main/kotlin/com/zeepowertoys/multidisplay_poc/MainActivity.kt:238–285`

`MinimapView extends TextureView implements TextureView.SurfaceTextureListener`. Key properties:
- `@Volatile var baseHue: Float = 200f` — mutable from main thread via `setMinimapParam`
- `@Volatile private var running = false` — render-thread stop flag
- `isOpaque = true` in `init` — so the native layer is fully opaque
- Render loop: `Thread { while (running) { lockCanvas(); draw(); unlockCanvasAndPost() } }`
- Frame rate: `Thread.sleep(16)` (~60fps)
- `onSurfaceTextureDestroyed`: sets `running = false`, interrupts render thread, returns `true`

The `FrameLayout` z-ordering is: `MinimapView` added first (z=0, bottom), then `FlutterView(ftv)` added second (z=1, top). Standard Android view stacking.

---

## 6. Dart-side Minimap MethodChannel

**File:** `_poc/multidisplay_poc/lib/main.dart:32–36`

```dart
const MethodChannel kMinimap = MethodChannel('zee/minimap');
```

Invocation pattern (line 114):
```dart
Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
  try {
    final Object? r = await kMinimap.invokeMethod<Object?>(method, args);
    setState(() => _lastCall = '$method ${args ?? ''} -> $r');
  } on PlatformException catch (e) {
    setState(() => _lastCall = '$method ERROR ${e.code} ${e.message}');
  }
}
```

Method signatures called from Dart:
- `kMinimap.invokeMethod('setMinimap', {'enabled': true|false})`
- `kMinimap.invokeMethod('setMinimapBounds', {'x': int, 'y': int, 'w': int, 'h': int})`
- `kMinimap.invokeMethod('setMinimapParam', {'key': 'hue', 'value': double})`

---

## 7. Secondary Display Discovery

**File:** `_poc/multidisplay_poc/android/app/src/main/kotlin/com/zeepowertoys/multidisplay_poc/MainActivity.kt:70–95`

```kotlin
private fun findSecondaryDisplay(): Display? {
    val dm = getSystemService(Context.DISPLAY_SERVICE) as android.hardware.display.DisplayManager
    val displays = dm.displays
    return displays.firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }
}
```

Called with a 1500ms delay after primary view is ready:
```kotlin
handler.postDelayed({ setupSecondaryDisplay(flutterEngine) }, 1500)
```

The overlay display for testing is set via:
```
adb shell settings put global overlay_display_devices 1280x720/213
```
(from the PoC pattern — the dev/emulator stand-in for the real HUD display).

---

## 8. Approach B — Custom GTK Two-Engine Runner (Desktop Fallback)

**Files:**
- `_poc/desktop_twoengine/approach_b/linux/runner/my_application.cc`
- `_poc/desktop_twoengine/approach_b/lib/main.dart`

This is the "own the host" fallback (ADR 0005 reference). No `desktop_multi_window` package. The runner calls `create_engine_window()` twice from `my_application_activate()`:

```cpp
static void create_engine_window(MyApplication* self, const char* title,
                                 char** entrypoint_args) {
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(self)));
  gtk_window_set_title(window, title);
  gtk_window_set_default_size(window, 1280, 720);
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, entrypoint_args);
  FlView* view = fl_view_new(project);
  // ...
  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  // PRIMARY: normal args
  create_engine_window(self, "approach_b — PRIMARY (own engine)",
                       self->dart_entrypoint_arguments);
  // HUD: forced arg "hud"
  char* hud_args[] = {const_cast<char*>("hud"), nullptr};
  create_engine_window(self, "approach_b — HUD (own engine)", hud_args);
}
```

The `G_APPLICATION_NON_UNIQUE` flag is required to allow the `activate()` signal to fire even if there's already a running instance (no single-instance restriction).

Dart dispatch in approach_b (line 42):
```dart
void main(List<String> args) {
  final bool isHud = args.contains('hud');
  _surface = isHud ? 'hud' : 'primary';
  _registerZee();
  runApp(isHud ? BApp(title: 'HUD', ...) : BApp(title: 'PRIMARY (DHU)', ...));
}
```

No `desktop_multi_window` dep. `pubspec.yaml` is stdlib-only (`cupertino_icons: ^1.0.8`).

---

## 9. Feedback Loop Drive Scripts

### zee_drive.py (canonical, in both `_poc/desktop_twoengine/drive/` and `_poc/feedback_loop/`)

**Files:**
- `_poc/desktop_twoengine/drive/zee_drive.py` (identical to)
- `_poc/feedback_loop/zee_drive.py`

Key design:
- `resolve_ws_uri()`: checks `$ZEE_VM_URI` override first, then scans `adb logcat -d -t 6000` for any of three VM service URI patterns, then calls `adb forward tcp:8181 tcp:<remote_port>` and returns a normalized `ws://.../<token>/ws` URI.
- `VMClient.rpc(method, params)`: thin JSON-RPC 2.0 over WebSocket, uses `asyncio.wait_for(..., timeout=30)` with ID matching.
- `VMClient.isolates()`: calls `getVM`, returns `vm["isolates"]`.
- `VMClient.resolve_isolate(selector)`: maps `None`→first isolate, or string matching by id/name/number, or `"primary"/"hud"` via `ext.zee.whoami` surface field.
- `_with_client(ws_uri, fn)`: connects with `max_size=8*1024*1024` (needed for base64 PNG payloads from `ext.zee.shot`).

CLI subcommands: `isolates`, `whoami-all`, `call <ext> [--isolate ...] [k=v ...]`.

Environment variables: `ADB_SERIAL` (default `emulator-5554`), `ZEE_LOCAL_PORT` (default `8181`), `ZEE_RPC_TIMEOUT` (default `30`), `ZEE_VM_URI` (override).

### probe.py (`_poc/desktop_twoengine/drive/probe.py`)

Automated four-step proof: (1) two isolates on one VM, (2) whoami surface map, (3) bump-diverge test, (4) pushConfig cross-engine relay. Port this as the skeleton's CI smoke test.

### grab_shots.py (`_poc/desktop_twoengine/drive/grab_shots.py`)

Iterates all isolates, calls `ext.zee.shot` on each, decodes `png_b64`, writes `shots/<surface>.png`. Use as visual regression baseline.

---

## 10. Imports Required (Android host)

From `MainActivity.kt` lines 1–30:
```kotlin
import android.app.Presentation
import android.view.Display
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
```

---

## 11. Lifecycle & Cleanup

```kotlin
override fun onDestroy() {
    try { presentation?.dismiss() } catch (_: Throwable) {}
    secondEngine?.destroy()
    super.onDestroy()
}
```

The `presentation?.dismiss()` is wrapped in try/catch because it can throw if the display has already gone. `secondEngine?.destroy()` must be called before `super.onDestroy()` to prevent engine leaks.

---

## 12. pubspec.yaml SDK Constraints

Both PoCs use `sdk: ^3.12.1`. No special Flutter constraints. `multidisplay_poc` has **zero** non-flutter pub deps (no `desktop_multi_window` needed on Android). `desktop_twoengine` uses `desktop_multi_window: ^0.3.0` for the Approach A relay only.

---

## 13. Key Design Invariants to Preserve When Porting

1. `_hub.setMethodCallHandler(...)` must be called in the **HUD** isolate's startup path only (not PRIMARY's), or the handler will be registered on the wrong side.
2. `WindowMethodChannel(kHubChannel, mode: ChannelMode.unidirectional)` — the `ChannelMode.unidirectional` is required; bidirectional would need both sides registered as handlers.
3. `@pragma('vm:entry-point')` on `hudMain()` — without this, tree-shaking in release builds will silently drop the entrypoint.
4. `ftv.isOpaque = false` — without this, `FlutterTextureView` renders opaque black regardless of Dart `backgroundColor: Colors.transparent`.
5. The `counter` / `tick` / `configFromMain` `ValueNotifier`s are all module-level globals. In each engine/isolate they are **distinct heap objects** with different `identityHashCode` values — this is the proof that engines are isolated.
6. `ext.zee.shot` requires `RepaintBoundary` wrapping at the root; otherwise `ctx.findRenderObject()` returns a non-`RenderRepaintBoundary` and the cast throws.
7. `handler.postDelayed({ setupSecondaryDisplay(...) }, 1500)` delay is a pragmatic wait for primary rendering; the walking skeleton should watch for a proper "first frame" callback instead of a fixed delay.


## Lift-ready artifacts

### desktop_twoengine main.dart
- **Source:** `/home/user/src/zee-power-toys/_poc/desktop_twoengine/lib/main.dart`
- **What:** Flutter desktop two-engine relay PoC: WindowMethodChannel Hub setup, ext.zee.* VM extension registrations (whoami/bump/pushConfig/shot via RepaintBoundary->base64 PNG), PRIMARY/HUD entrypoint dispatch, idempotent HUD window creation
- **Reuse:** Port the _registerZeeExtensions() function verbatim into the new app's main.dart. Copy the kHubChannel constant, WindowMethodChannel declaration, _pushConfigToHud(), and the main() args-dispatch pattern. Wrap root widgets in RepaintBoundary(key: _shotKey). Replace PrimaryApp/HudApp content with real DHU/HUD widgets.

### desktop_twoengine pubspec.yaml
- **Source:** `/home/user/src/zee-power-toys/_poc/desktop_twoengine/pubspec.yaml`
- **What:** pubspec declaring desktop_multi_window: ^0.3.0 as the only non-Flutter dep, sdk: ^3.12.1
- **Reuse:** Add desktop_multi_window: ^0.3.0 to the new app's pubspec.yaml dependencies. The sdk constraint ^3.12.1 is the minimum required.

### approach_b my_application.cc
- **Source:** `/home/user/src/zee-power-toys/_poc/desktop_twoengine/approach_b/linux/runner/my_application.cc`
- **What:** Custom GTK two-engine runner (Approach B fallback): create_engine_window() called twice in activate(), fl_dart_project_set_dart_entrypoint_arguments() used to pass 'hud' arg to second engine. No desktop_multi_window package required.
- **Reuse:** Use as fallback if desktop_multi_window is unavailable or unstable. Copy create_engine_window() helper and the two-call pattern in my_application_activate(). Set G_APPLICATION_NON_UNIQUE in my_application_new(). The Dart side checks args.contains('hud') — no 'multi_window' prefix needed.

### multidisplay_poc MainActivity.kt
- **Source:** `/home/user/src/zee-power-toys/_poc/multidisplay_poc/android/app/src/main/kotlin/com/zeepowertoys/multidisplay_poc/MainActivity.kt`
- **What:** Android FlutterEngineGroup host: Exp2 (two-engine Presentation on secondary display), Exp3 (transparent FlutterTextureView overlay over native MinimapView), zee/minimap MethodChannel handler with idempotent setMinimap, setMinimapBounds, setMinimapParam(hue), display discovery, lifecycle cleanup
- **Reuse:** Port setupExp2EngineGroup() for the HUD engine instantiation. Port setupExp3Transparent() verbatim for the minimap+overlay layer, keeping ftv.isOpaque = false. Port handleMinimap() as the zee/minimap channel handler. Port MinimapView class as the native animated TextureView. Port onDestroy() cleanup pattern. Rename class/package as needed.

### multidisplay_poc main.dart (Dart side)
- **Source:** `/home/user/src/zee-power-toys/_poc/multidisplay_poc/lib/main.dart`
- **What:** Flutter dual-entrypoint: main() for PRIMARY, hudMain() for HUD (with @pragma vm:entry-point). ext.zee.whoami+bump registrations. kMinimap MethodChannel declaration and invocation pattern. HudOverlay with transparent Scaffold.
- **Reuse:** Copy hudMain() entrypoint pattern with @pragma('vm:entry-point') annotation verbatim. Copy _registerZeeExtensions() for the Android variant (whoami+bump only, no pushConfig/shot needed for Android). Copy const kMinimap = MethodChannel('zee/minimap') and _invoke() helper. Copy HudOverlay's backgroundColor: Colors.transparent Scaffold structure.

### zee_drive.py (feedback loop client)
- **Source:** `/home/user/src/zee-power-toys/_poc/feedback_loop/zee_drive.py`
- **What:** Minimal Dart VM service client: adb logcat VM URI discovery, adb port forwarding, WebSocket JSON-RPC, isolate listing (getVM), isolate resolver by surface name (ext.zee.whoami), CLI subcommands isolates/whoami-all/call
- **Reuse:** Copy as the project's canonical zee_drive.py under tools/ or drive/. The VMClient class and resolve_ws_uri() function are drop-in reusable. The resolve_isolate() surface-matching logic is the key piece for addressing primary vs hud isolates. Add new subcommands as needed without modifying the core VMClient.

### probe.py (automated two-engine relay proof)
- **Source:** `/home/user/src/zee-power-toys/_poc/desktop_twoengine/drive/probe.py`
- **What:** Automated four-step proof script: two-isolate count verification, whoami surface map, bump-diverge memory isolation proof, pushConfig cross-engine relay proof via Hub channel
- **Reuse:** Port as the walking skeleton's CI smoke test. Replace assert len(isos) == 2 check, adapt for Android (zee_drive with adb) or desktop (ZEE_VM_URI). The four-step structure maps directly to ADR 0004 validation criteria.

### grab_shots.py (per-isolate screenshot via VM service)
- **Source:** `/home/user/src/zee-power-toys/_poc/desktop_twoengine/drive/grab_shots.py`
- **What:** Iterates all VM isolates, calls ext.zee.shot on each, decodes png_b64, writes shots/<surface>.png
- **Reuse:** Use as visual regression baseline and manual verification tool. Keep as-is; it uses zee_drive.VMClient so it works for any app that registers ext.zee.shot.


## Concrete API surface

- desktop_multi_window: ^0.3.0 (pub.dev package)
- WindowMethodChannel(channelName, mode: ChannelMode.unidirectional)
- ChannelMode.unidirectional
- WindowController.create(WindowConfiguration(arguments: 'hud', hiddenAtLaunch: true))
- WindowController.show()
- WindowController.windowId
- WindowMethodChannel.invokeMethod(methodName, arguments)
- WindowMethodChannel.setMethodCallHandler(handler)
- developer.registerExtension('ext.zee.whoami', handler)
- developer.registerExtension('ext.zee.bump', handler)
- developer.registerExtension('ext.zee.pushConfig', handler)
- developer.registerExtension('ext.zee.shot', handler)
- developer.ServiceExtensionResponse.result(jsonString)
- RenderRepaintBoundary.toImage(pixelRatio: 1.0)
- ui.Image.toByteData(format: ui.ImageByteFormat.png)
- GlobalKey (for RepaintBoundary in ext.zee.shot)
- @pragma('vm:entry-point') on hudMain()
- FlutterEngineGroup(context)
- FlutterEngineGroup.createAndRunEngine(context, DartEntrypoint)
- DartExecutor.DartEntrypoint(flutterLoader().findAppBundlePath(), 'hudMain')
- FlutterInjector.instance().flutterLoader().findAppBundlePath()
- FlutterEngine.lifecycleChannel.appIsResumed()
- FlutterEngine.destroy()
- FlutterTextureView(context)
- FlutterTextureView.isOpaque = false
- FlutterView(context, FlutterTextureView)
- FlutterView(context, FlutterSurfaceView(context))
- FlutterView.attachToFlutterEngine(engine)
- FlutterView.isAttachedToFlutterEngine
- android.app.Presentation(context, display)
- Presentation.setContentView(view)
- Presentation.show()
- Presentation.dismiss()
- android.hardware.display.DisplayManager.getDisplays()
- Display.DEFAULT_DISPLAY
- Display.displayId
- FrameLayout.LayoutParams(w, h).apply { leftMargin; topMargin }
- View.VISIBLE / View.INVISIBLE (for idempotent setMinimap)
- View.requestLayout()
- MethodChannel('zee/minimap')
- MethodChannel('zee/hub') [desktop: WindowMethodChannel('zee/hub')]
- MethodCall.argument<T>(key)
- MethodChannel.Result.success(value)
- MethodChannel.Result.notImplemented()
- TextureView (MinimapView base class)
- TextureView.SurfaceTextureListener (interface implemented by MinimapView)
- TextureView.lockCanvas() / unlockCanvasAndPost(canvas)
- SurfaceTexture (parameter in onSurfaceTextureAvailable)
- Handler(Looper.getMainLooper()).post { }
- Handler.postDelayed({ }, 1500)
- Context.DISPLAY_SERVICE
- VMClient.rpc(method, params) -> JSON-RPC 2.0 over WebSocket
- VMClient.isolates() -> getVM isolates list
- VMClient.resolve_isolate(selector) -> isolateId
- websockets.connect(uri, max_size=8*1024*1024)
- adb forward tcp:LOCAL tcp:REMOTE
- adb logcat -d -v brief -t 6000
- ZEE_VM_URI env var (override for VM service URI)
- ADB_SERIAL env var (default: emulator-5554)
- ZEE_LOCAL_PORT env var (default: 8181)
- ZEE_RPC_TIMEOUT env var (default: 30s)

## Risks

- ftv.isOpaque = false is undocumented behavior on FlutterTextureView; if Flutter changes the compositing path in a future version, the transparent overlay may stop working. Test on the actual car's Android build.
- The 1500ms handler.postDelayed() before setupSecondaryDisplay() is a timing hack. On a slower car head-unit the primary engine may not be ready in 1500ms; on a fast device it may waste time. Replace with a proper first-frame callback (FlutterView 'onFirstFrame' or EngineLifecycleListener).
- @pragma('vm:entry-point') is required for hudMain() in release builds. If it is ever accidentally removed or the pragma syntax changes, DartEntrypoint('hudMain') will crash with a cryptic 'no such entrypoint' error at runtime.
- desktop_multi_window 0.3.0 uses an in-process ChannelRegistry for unidirectional WindowMethodChannel routing. If two HUD windows are accidentally created (missing idempotency guard), the second call to setMethodCallHandler will overwrite the first, silently dropping pushConfig messages.
- The MinimapView render thread accesses @Volatile baseHue from the main thread and the render thread concurrently without a lock. For a color float this is safe on JVM, but if the real minimap uses more complex shared state, a lock or AtomicReference is needed.
- FlutterEngineGroup.createAndRunEngine() is synchronous but the engine starts asynchronously. fv.attachToFlutterEngine(eng) called immediately after may attach before the engine's first frame, causing a blank Presentation for a brief period. The PoC tolerates this; the production app should handle the loading state.
- The overlay display set via 'adb shell settings put global overlay_display_devices 1280x720/213' is an emulator/dev stand-in. The real Zeekr car's HUD display will appear as a different DisplayId (likely id=1 or id=2) with its own resolution and density. Display discovery must be validated on the actual hardware.
- The zee_drive.py logcat scan reads the last 6000 lines (-t 6000). On a heavily-used device with many log entries this may not go back far enough to find the VM service URI if the app was started a long time ago. The '--vm-uri' / '$ZEE_VM_URI' override is the reliable path for CI.
- approach_b (custom GTK runner) has no inter-engine channel (no desktop_multi_window, no Hub). It proves isolated heaps but does NOT demonstrate config relay. If desktop_multi_window breaks, approach_b would need the Hub wired manually via fl_method_channel in C++, which is significantly more complex.
- ext.zee.shot's RepaintBoundary.toImage() is called on the UI isolate; for large screens at high pixel ratios this can take >16ms and cause a frame drop. Keep pixelRatio at 1.0 (as the PoC does) for diagnostic use only; never call it in a hot path.