---
status: done
labels: [hud, minimap, t3]
created: 2026-09-19
satisfies: HUD · Minimap
blocked-by: []
modules: [MinimapHost, MinimapConfig, ConfigStore]
tier: T3
---

# 0028 — Minimap too large / no content density + phase0 look parity

## Block scope
Customer (Maxim, on-car): minimap **boundary** is too large and there is **no control for content/density inside** the square (only Compact/Balanced/Large viewport size). Look/filter also differs from **zee_hud_2 / phase0** on the car.

Deliver:
1. **Content density / zoom-in-viewport control** in DHU Minimap settings (phase0 `minimapScale`-style: more map area in the same boundary — not just resizing the square). Wire through ConfigStore → native (`bufScale` / real phase0 `minimapScale` path — measure what actually changes density on T2/T3; do not ship a dead knob).
2. **Default look = phase0 White** (contrast **3.0**, threshold **150**, white preset) and ensure **existing car prefs migrate or reset** so T3 doesn’t keep cyan/3.5/165 forever.
3. **A/B vs phase0 on car:** phase0 package `com.zeekr.phase0` is still installed (`enabled=3` disabled-user). Prefer dump phase0 `hud_settings` / viewport prefs when readable; else enable briefly per `docs/knowledge/phase0-ynavi-ab-testing.md`, capture optics, then re-disable. Match look + density to that baseline.

## Touches
- **Satisfies:** HUD · Minimap
- **Modules:** MinimapHost, MinimapConfig UI, ConfigStore
- **Refs:** `zee_hud_2/phase0-diagnostics/YNAVI.md` (White default, contrast 3.0, threshold 150, `minimapScale`); BACKLOG note that `bufScale`/`dpiScale` alone may not zoom — verify on-car before claiming.

## Definition of Done
- [x] DHU UI exposes content-density control; runtime-confirmed on **T3** optics (or T2 if density lever proven there) with before/after shots
- [x] Look matches phase0 White baseline (migrate + defaults; optics A/B = QA) on optics (shot vs phase0 reference)
- [x] Fresh + existing-prefs paths both end on White/3.0/150 (migrate or documented clear)
- [ ] phase0 left disabled-user after A/B

## Notes
Customer ask 2026-09-19. Upstream YNavi label/zoom (`ZEEAPP_MAP_SCALE_PERCENT`) remains separate if density lever is insufficient.
## Progress (2026-09-19)
- Prefs schema v2: migrate existing installs → White/3.0/150 + `advanced=false` (unlocks presets).
- Removed Advanced ExpansionTile; Size slider always visible next to Compact/Balanced/Large.
- Still TODO: content-density (`minimapScale`/`bufScale`/`dpiScale`) + optics A/B vs phase0.
### Dev tip (2026-09-19)
- `contentScale` (phase0 `minimapScale`, default 0.5) in Minimap settings + native cold rebind on change.
- Buffer = viewport / scale (phase0 formula). QA: optics A/B vs phase0 still required for T3 clear.
