---
status: done
labels: [hud, minimap, config]
created: 2026-06-11
satisfies: HUD · Minimap configuration — YNavi enable/disable, presets, basic/advanced, dark-light auto
blocked-by: [0009, 0011]
modules: [MinimapHost, ConfigStore, SystemConfig]
tier: T1
---

# 0013 — Minimap configuration UI

## Block scope
A localized DHU **Minimap** config screen: **enable/disable** the YNavi minimap (the toggle is **disabled with an explanation when no compatible YNavi mod is installed** — REQUIREMENTS), **basic vs advanced** modes (presets vs manual dimensions/looks), and a **dark/light preset that follows the system theme** (which tracks external luminosity). Drives `MinimapHost` (→ native `setMinimap`/`bounds`/`params` on T2, proven in 0009). Defaults excellent; advanced is opt-in (fight bloat).

## Touches
- **Satisfies:** REQUIREMENTS — "Enabling and configuring YNavi minimap…"; "Disable YNavi in HUD if no compatible YNavi mod is installed"; "basic and advanced config modes (presets + manual controls of dimensions, looks)"; "choose preset for dark/light theme following system change."
- **Modules:** MinimapHost (drive), ConfigStore (minimap schema), SystemConfig/theme (dark/light).
- **ADRs:** 0001 (Minimap), 0003/0006.

## Grounding
- YNavi package + detection + mod specifics: [`docs/knowledge/ynavi-bind-and-mod.md`](../knowledge/ynavi-bind-and-mod.md) (the YNavi mod package name(s) to detect; how to know a compatible mod is installed).
- MinimapHost + native under-layer: `lib/services/minimap_host.dart`, `lib/services/adapters/native_minimap_host.dart` (enable/bounds/params over `zee/minimap`), `lib/services/fakes/fake_minimap_host.dart`.
- Nav/l10n/theme: `lib/screens/settings_home_screen.dart`, `lib/l10n/*.arb`, the DHU MaterialApp theme.

## What to build
- **YNavi detection:** a native check (PackageManager: is a compatible YNavi-mod package installed?) surfaced to Dart (e.g. `MinimapHost.isYnaviAvailable()` or a `SystemConfig`/native method). On the emulator → **false** → the enable toggle is disabled with a localized "Install a compatible YNavi mod" hint. On T1 desktop → a fake returns a configurable value (default false, or a debug override) so the UI states are testable.
- `MinimapConfig { bool enabled; MinimapPreset preset; bool advanced; Rect bounds?; ThemeFollow themeFollow (auto/dark/light); ... }` in AppConfig (plain JSON; excellent defaults). `minimapConfigProvider`.
- `lib/screens/minimap_settings_screen.dart` — enable toggle (gated by YNavi availability), basic preset selector, an "Advanced" expander with manual dimension/looks controls, and a dark/light-follows-system selector. Live preview where meaningful. Wire into the Settings hub (add a "Minimap" or "HUD → Minimap" entry; or a subsection of HUD settings).
- **Dark/light auto:** when `themeFollow=auto`, the HUD/preview palette follows the system brightness (`MediaQuery.platformBrightness`); dark/light force the respective preset. (App policy in Dart, ADR 0003.)
- On enable change → `MinimapHost.enable(bool)` (drives native setMinimap on T2). Persist all config.
- `ext.zee.*`: `setConfig` accepts minimap keys (`minimapEnabled`, `minimapPreset`, `minimapTheme`); readViewModel includes minimap config + `ynaviAvailable`.

## Definition of Done (runtime-confirmed on T1)
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] Minimap config screen renders, localized; YNavi unavailable → enable toggle disabled + explained. — artifact: [`shots/minimap-config.png`](../../shots/minimap-config.png) (RU: toggle off+greyed, "Установите совместимый мод YNavi…", presets, theme follow).
- [x] `minimapEnabled`/preset/theme persist; dark/light-auto follows system; on T2 enable→`setMinimap` (proven in 0009). — artifact: readViewModel `minimap{enabled,preset,advanced,themeFollow,ynaviAvailable:false,resolvedBrightness}`.
- [x] analyze clean; **146 tests** green (config round-trip; enable gated by ynaviAvailable; ARB parity); build linux+apk ok; no regression. Principles: excellent defaults, advanced opt-in.

## Reconciliation
Built by Sonnet, runtime-verified by the orchestrator (Opus) on T1, 2026-06-11.
1. **YNavi detection** = native `PackageManager.getPackageInfo("ru.yandex.yandexnavi", GET_SERVICES)` + a `NavigationCarAppService` declaration check (knowledge §7 steps 1–2). Absent on emulator/T1 → false → toggle gated. Step 3 (bind probe) + step 4 (signing-key discriminator: AOSP-debug-signed mod vs Yandex-release stock) deferred to **T3**.
2. **Dark/light**: `themeFollow ∈ {auto,dark,light}` persisted; `auto` resolves via `MediaQuery.platformBrightnessOf` at render (no BuildContext in the VM extension, so `readViewModel.resolvedBrightness` reports the config token).
3. The real YNavi map + trip data (bind) is T3; this Block delivers config + detection + the drive path (setMinimap proven on T2 in 0009).

## Notes
The real YNavi map pixels + trip data (bind) are T3 (real mod on the car). This Block delivers the config + detection + the drive path (setMinimap proven on T2 in 0009 with the placeholder).
