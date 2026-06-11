# Zee Power Toys

A customization and utility app for a Zeekr car's Android head unit. It controls what is drawn on the windshield HUD — navigation minimap, turn signals, speed-camera alerts, charging and battery info — and exposes car configuration (language, downloads, diagnostics) through a touchscreen app.

## Language

### Surfaces

**HUD**:
The head-up display projected onto the windshield. An emissive projector: black pixels emit no light and read as transparent, so HUD content is bright marks on black (never light-on-dark UI). Its optics only reveal a sub-rectangle of the backing display, so all content must stay inside the Safe Area.
_Avoid_: heads-up display, windscreen display

**Safe Area**:
The portion of the HUD's backing display actually visible through the projector optics. A fixed, hand-calibrated rectangle; content outside it is clipped or invisible.
_Avoid_: visible bounds, HUD bounds, viewport

**Cluster**:
The instrument-cluster display behind the steering wheel. A distinct surface from the HUD.
_Avoid_: dashboard, gauge cluster

**DHU**:
The car's Digital Head Unit — the Android 12L computer the app runs on, with the central touchscreen as its primary display.
_Avoid_: head unit, infotainment, IVI

### HUD content

**Minimap**:
The navigation map shown on the HUD. Drawn by YNavi into a surface we host — it is foreign content, not something we render.
_Avoid_: map view, nav map

**Blinker**:
The turn-signal indicator drawn on the HUD.
_Avoid_: turn signal, indicator, arrow

**Speedcam**:
The speed-camera proximity indicator on the HUD. "Radar" and "alien mode" are visual *styles* of the Speedcam, not the concept itself.
_Avoid_: speed camera alert, radar

**Guidance**:
The turn-by-turn overlay we draw on the HUD (turn arrow, distance, road name, ETA) from YNavi trip data. Distinct from the Minimap, which YNavi draws.
_Avoid_: TBT overlay, nav overlay, chrome

### Integrations

**YNavi**:
The modified Yandex Navigator APK we bind to as a CarApp host to obtain the Minimap surface and live trip data.
_Avoid_: Yandex Navi, Navigator, nav app

### Services

**Service**:
A component owning one slice of truth, exposing events (out) and commands (in), injected as a port so its host swaps per tier (real native ↔ Dart fake) while the Dart app logic stays identical.
_Avoid_: manager, module, layer

**CarSignals**:
The service exposing live car-interop truth (speed, blinker, charge) as events. Native AdaptAPI on the car; a Dart fake off-car.
_Avoid_: CarApi, sensors, telemetry

**ConfigStore**:
The service owning persisted app preferences — one Dart-defined schema and one plain persisted format on every tier.
_Avoid_: settings, prefs, SharedPreferences

**MinimapHost**:
The service wrapping the YNavi native sidecar that produces the Minimap, driven by Flutter through a lean idempotent command API.
_Avoid_: map service, ynavi bridge

**HudHost**:
The service owning the HUD surface lifecycle — creating the Presentation/window and applying the Safe Area.
_Avoid_: presentation manager, display host

### Feedback Loop

**Feedback Loop**:
The harness that drives the app and reads its state for agentic development. Two channels (VM-service for UI + view-model; native ADB/broadcast for signal injection + native-state inspection) behind one tier-agnostic client.
_Avoid_: test harness, debug bridge, automation

**Tier**:
One of three progressively more faithful environments the Feedback Loop runs in. Each must offer both state insight and end-to-end UI driving.
_Avoid_: mode, environment, stage

**T1 Desktop**:
The macOS/Linux tier — pure-Dart fakes, no Android, fastest iteration. The UI-iteration workhorse.
_Avoid_: fake tier, local

**T2 Emulator**:
The Android-emulator tier — real native plumbing driven by the native simulator. Validates the native edge without a car.
_Avoid_: sim tier

**T3 Car**:
The on-DHU tier — real AdaptAPI, real YNavi, real HUD optics. The source of truth for fidelity.
_Avoid_: prod tier, real tier, device
