---
status: done
labels: [hud, minimap, ynavi]
created: 2026-09-20
satisfies: HUD · Minimap
blocked-by: [0055, 0056]
modules: [MinimapHost, MinimapConfig, HudRoot, main]
tier: T1
owner: zee-dev
---

# 0057 — Show minimap only while YNavi guidance active

## Block scope
Zee HUD 2 toggle: when on, show the YNavi minimap surface **only while
navigation guidance is active**. Default **off** = always show whenever
minimap is enabled (today’s behaviour).

Persist the flag. Soft-hide the TextureView via `setSurfaceVisible` on real
navigation truth (`INavigationHost.navigationStarted` / `navigationEnded` via
`onNavState`) — keep the YNavi bind alive while `enabled` so future starts
are heard. Not “config says enabled” alone, and not a stale trip event.

## Touches
- **Satisfies:** HUD · Minimap (guidance-gated visibility)
- **Modules:** `MinimapConfig.onlyWhileGuidance`, `MinimapHost.navigationActive`,
  Native/Fake adapters, `_applyMinimapConfig`, Minimap settings UI, HudRoot chrome
- **Prior:** [0055](0055-ynavi-minimap-info-overlay.md) overlay stays; do not drop

## Definition of Done
- [x] `onlyWhileGuidance` default `false`; JSON persist
- [x] Native forwards `onNavState` → Dart `navigationActive` stream
- [x] `_applyMinimapConfig` keeps bind when enabled; `setSurfaceVisible` iff `enabled && (!onlyWhileGuidance || navActive)`
- [x] DHU Minimap settings toggle + EN/RU
- [x] HudRoot glyph/0055 overlay follow the same gate
- [x] Unit/widget tests green
- [x] Tip; car install = `adb install -r` only (0054)

## Notes
Distinct from phase0 `guidanceModeOnly` (hide map, show TBT only). This Block
hides the whole minimap until guidance is active.

## Reconciliation
`enable(false)` stops YNavi — cannot hear `navigationStarted` afterward.
0057 soft-hides via `setMinimapSurfaceVisible` / `setSurfaceVisible` while
keeping the bind when `enabled` is true. Nav-session truth from `onNavState`
(not trip-row inference). Guidance trip rows still relay DHU→HUD (0055 FAIL).
