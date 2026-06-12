---
status: done
labels: [foundation, feature, ui, navigation]
created: 2026-06-12
satisfies: HUD · Minimap (real YNavi cluster surface) + cross-cutting UI quality
blocked-by: []
modules: [Theme, DHU UI, HudHost, MinimapHost]
tier: T1+T2
---

# 0018 — Premium DHU UI + real YNavi CarApp host (bind-confirmed)

## Block scope
Two entangled deliverables that together make the MVP feel like a real product on the
**low-DPI (160) DHU** and wire the **real** navigation surface:

1. **Premium DHU UI** — the app had no `ThemeData`, so default light-M3 over-scaled on the
   160 dpi DHU (the "blind-person accessibility" look). A dark, premium M3 theme + a shared
   settings layout + a text-scale clamp fix it. The blinker, previously a half-screen
   chevron/dot-stack, is now a small amber circle (matches the real car blinker the user runs).
2. **Real YNavi CarApp host** — ports phase0's validated CarApp AIDL host so the HUD can
   render Yandex Navigator's cluster surface instead of the placeholder minimap. The bind +
   handshake + `onSurfaceAvailable` + location streaming are runtime-confirmed on T2; the
   actual map-pixel render is tracked as the open seam for Block 0019 (see Deferred).

## Touches
- **Satisfies:** HUD · Minimap (real YNavi surface lands the long-promised cluster map);
  cross-cutting UI quality (Principle 1 — excellent defaults, no bloat).
- **Modules:** Theme (new), DHU UI (all settings screens), HudHost (blinker/battery optics),
  MinimapHost (real YNavi surface path).
- **ADRs:** 0001 (HUD emissive rendering / two-engine), 0005 (native edge), 0002 (one artifact),
  0007 (delivery discipline).

## What this Block delivered

### 1. Premium DHU theme — `lib/theme/app_theme.dart` (T1)
A single dark Material-3 `AppTheme.dhu` with deliberate tokens (`Insets`, `Radii`, `Sizes`,
`AppColors` — bg `#0C0E12`, Zeekr-cyan accent `#35C2E8`). Wired into `dhu_app.dart` and
`hud_app.dart` with `MediaQuery.withClampedTextScaling(1.0, 1.0)` so the 160 dpi DHU renders
crisp, product-grade UI instead of OS-inflated controls.

### 2. Shared settings layout — `lib/widgets/settings_layout.dart` (T1)
Consistent section/card/row primitives so every settings screen (home, diagnostics,
HUD, minimap, language, install) shares one premium look. All six DHU screens restyled.

### 3. Small-circle blinker — `lib/hud/blinker_widget.dart` (T1)
`_CircleShape` (base Ø 18, amber `#FFC107`) replaces the oversized chevron/dot rendering.
The production HUD now emits a small, correctly-shaped light mark. Battery slot inset
nudged inside the Safe Area (`right: saWidth*0.008, top: saHeight*0.010`).

### 4. Real YNavi CarApp host — `android/.../carapp/` (bind-confirmed T2)
`YNaviCarAppHost.kt` + `IAppHostStub.kt` + `ICarHostStub.kt` bind
`ru.yandex.yandexnavi/.projected.platformkit.presentation.service.NavigationCarAppService`
via host-side `androidx.car.app:app:1.4.0` AIDL. Handshake: `onHandshakeCompleted(LEVEL_1)`
→ `onAppCreate(SessionInfo DISPLAY_TYPE_CLUSTER)` → `onAppStart` → `onAppResume` →
`getManager(app)` → `startLocationUpdates` → `setSurfaceCallback` → `onSurfaceAvailable`.
`sessionEpoch` (AtomicInteger) + ordered teardown fix the stop→start unbind race.
`MainActivity` drives the host by `enabled && isActive` state (not the old visibility NOOP),
passes the HUD presentation display density, and routes the `MinimapView` surface to the host.
`build.gradle.kts` adds the dependency + disables the `RestrictedApi` lint for the host-side
AIDL.

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] `flutter analyze` clean; **191 tests** green.
- [x] Android **debug APK builds** (compiles the new Kotlin host + car-app dependency).
- [x] Premium DHU UI runtime-confirmed on **T1** — artifacts: `shots/redo/t1-dhu-home.png`,
      `shots/redo/t1-diagnostics.png` (dark premium M3, crisp at 160 dpi, no over-scale).
- [x] Small-circle blinker runtime-confirmed on **T1** — `shots/redo/t1-hud-blinker.png`
      (small amber circle + battery widget; emissive-black background).
- [x] YNavi CarApp host **bind** runtime-confirmed on **T2** — logcat: `onSurfaceAvailable
      SUCCESS` + `startLocationUpdates` streaming on the bound `NavigationCarAppService`.
- [x] Trunk green — no regression to prior Blocks.

## Reconciliation
- **BACKLOG.md** — added this Block (0018) to the board.

## Deferred (tracked, honest — not silently shipped)
1. **YNavi cluster MAP render (Block 0019)** — the host *binds* and YNavi streams location,
   but the cluster map pixels are not yet drawn onto our HUD surface. phase0's proven recipe
   (verified on the emulator 2026-02-21, `docs/.../31_7_2_EMULATOR_E1_NAVIGATION_REPORT.md`)
   is identified: `pm clear ru.yandex.yandexnavi` + adb-grant location perms (cached state was
   phase0's #1 gotcha), P9 `HasPlus` bypasses the paywall so the map renders despite emulator
   Play-Integrity failure, plus the host-side fixes (surface-readiness race, navigation-manager
   fetch + one-shot template probe) that diverge from phase0's `CarAppHostService`.
2. **Carried from 0017** (still open): minimap-config → MinimapHost wiring; real `install_targets`
   asset names; native dedup automated test; HUD-engine runtime teardown on `hudEnabled=false`.

## Notes
The premium UI + blinker were the user's explicit "must not suck on the 160 dpi DHU" bar; the
real YNavi host replaces the green placeholder minimap. The map render is the next seam (0019),
de-risked by the recovered phase0 recipe.
