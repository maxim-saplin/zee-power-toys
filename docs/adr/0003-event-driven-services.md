# 0003 — Event-driven services; Dart owns the brain; state derived per isolate

Flutter-first (ADR 0001) runs **two Flutter engines = two isolates** on every tier (Android: `FlutterEngineGroup`; desktop T1: two-engine runner / `desktop_multi_window` — both PoC-proven: same process, two isolates, one VM service). We must say where truth lives and how the two isolates coordinate — *without* a single commander. The desktop tier is the proof there is none: T1 has no native code at all, yet the whole system runs. So "native is the source of truth / commands the system" is simply false.

**Decision:** The system is a set of **services**, each owning one slice of truth and exposing **events** (streams out) and **commands** (calls in). The **application brain — policy and view logic — is Dart**, identical on every tier ("when charging → show the charging widget on the HUD" is app policy, not a car concern; CarSignals merely emits `charging=true`). Each service is a **port** (ADR 0002); per tier only the *host that provides* it swaps, never the brain:

- **CarSignals** — live car-interop truth (speed, blinker, charge). Host: native AdaptAPI on the car; Dart fake off-car.
- **MinimapHost** — the YNavi native sidecar (own lifecycle); commands `enable`/`bounds`/`params`, events = trip data. Host: native on the car; stub off-car.
- **ConfigStore** — persisted app preferences. **One Dart-owned service: the same schema, validation, and plain persisted format on every tier.** *Not* native-prefs-on-car / Hive-on-laptop.
- **HudHost** — HUD surface lifecycle (create the Presentation/window, apply the Safe Area). Host: native Presentation on the car; second window on desktop.

"Source of truth" therefore **decomposes per service** — CarSignals owns signal truth, ConfigStore owns config truth, the UI owns view truth. There is no global owner. Native is **not** a commander; it is only (a) the host of services that physically need it, (b) a relay across the isolate boundary, and (c) a thin boot shim.

**ConfigStore is identical across tiers.** Its on-disk form is a **plain, native-readable format** (not Hive's Dart-only binary) for exactly one reason: at power-on the native **boot shim** must read it — before any Flutter isolate exists — to decide which engines to start (is the HUD enabled, which features). That single privileged *read* is native's only config role; it neither owns nor arbitrates config. Off-car there is no boot shim, but the store and its format are the same.

**Cross-isolate coordination:** only **events and commands cross the isolate boundary** — serializable messages over the platform transport (native relay on Android; host channel on desktop, PoC-proven). **Never a shared mutable Dart object.** Each isolate runs the same `lib/`, subscribes to the same event streams, and **derives its own view-state locally**; two isolates fed identical events converge by construction. A config edit flows `DHU setConfig command → ConfigStore persists → changed event → both isolates re-derive` — no sync protocol, no special-casing.

**Consequences:**
- The **relay transport** is the only per-tier difference in coordination (native on Android, host channel on desktop) — a property of the platform boundary, not of any service.
- The hardest path — cross-isolate propagation — runs on **every** tier, including the fast T1 loop, because T1 is deliberately two-isolate (faithful to target), not a single-isolate shortcut.
- Native's footprint is small and dumb: host native-only services, relay events/commands, run a ~tiny boot shim. The intelligence is Dart.
- Persisted config must be plain/native-readable (boot shim) — the ConfigStore port's implementation is the same on every tier.
- Empirically (PoCs `_poc/multidisplay_poc`, `_poc/desktop_twoengine`), the two isolates never share memory — a counter bumped in one stayed put in the other; a pushed config value reached the other isolate only via the relay — confirming the event-relay model on both Android and desktop.
- State management *within* an isolate — deriving view-state from event streams and injecting services per tier — is ADR 0006.
