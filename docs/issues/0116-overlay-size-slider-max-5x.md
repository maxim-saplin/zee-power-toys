---
status: accepted
tip: 74edf87
accepted: 2026-09-26
evidence: tmp/qa/0116-cut-74edf87/
labels: [hud, overlay, settings]
created: 2026-09-26
satisfies: Overlay size slider max grows ~5× so top end hits proper DHU dimensions
tier: T2
owner: zee-dev
blocked-by: []
modules: [Overlay size settings, HudOverlay / ZeeUiScale]
priority: now
filed-by: zee-pdm
related: [0106]
parent: [0106]
gate: armed-2026-09-26
---

# 0116 — Overlay size slider max ≈ 5× (proper DHU dimensions)

## Block scope

Maxim 2026-09-26 ~13:17 Minsk: after 0106, overlay size is **still too small** and the **slider range is inadequate**. **Current slider max must grow the overlay about five times** so the top end reaches proper dimensions on the car/DHU.

## Product rules

1. Raise the **maximum** of the overlay-size control so max ≈ **5×** today’s max scale (or equivalent linear factor that yields ~5× visual size — measure, don’t guess).
2. Existing user prefs: map old stored value into the new scale without a sudden jump to tiny/huge if possible; document migration.
3. Preview / Tablet dens320 must show max ≈ proper large HUD; min still usable.
4. Confirm control is not a no-op (0106).

## DoD (T2 dens320 + soft car)

- [x] Slider max visibly ~5× prior max footprint (measure HUD secondary / Flutter size)
- [x] Mid and min still usable; prefs migrate sanely
- [x] Soft: car T3 confirm “proper dimensions” — soft stand (Tablet clip at 8.0; not a blocker).
- [x] QA dens320 + four-point + PDM ACCEPT — PASS / ACCEPT `74edf87` (2026-09-26). Soft: car T3; Tablet clip 8.0→2560×1480.

## Soft / residuals

- Exact max number left to measure on Tablet + Maxim car taste; tip documents chosen factor.
- Soft car T3 dens clearance / “proper dimensions” taste.
- Did **not** implement 0115.

## Reconciliation

**2026-09-26 tip:** Overlay size slider max **1.6 → 8.0** (= **5×** prior max). Absolute scale vs base 280dp; identity prefs migration.

### Factor chosen (measure)

| | Prior max (1.6) | New max (8.0) | Ratio |
|--|--|--|--|
| Scale | 1.6 | **8.0** | **5.000×** |
| dens320 (d=2) px | 896×657 | **4480×3285** | 5.000× linear |
| DHU dens≈1 px | 448×329 | **2240×1643** | 5.000× linear (~87%×103% of 2560×1600) |
| Min (0.6) dens2 | 336×246 | unchanged | usable |
| Mid (1.0) dens2 | 560×411 | unchanged | usable |

Constants: `kSpeedcamOverlaySizeScaleMin/Max` (Dart) ↔ `OVERLAY_SIZE_SCALE_MIN/MAX` (Kotlin).

### Migration

**Identity** — `overlaySizeScale` remains an absolute multiplier of base **280dp**. Expanding the clamp upper bound **1.6 → 8.0** does **not** remap stored values: a pref of `1.2` stays `1.2` and paints the same px footprint. `SpeedcamConfig.fromJson` clamps to the new range only; values already in 0.6–1.6 load unchanged (unit-covered).

### Changes

1. **Range:** slider / prefs / Kotlin `setLayout` coerce **0.6–8.0** (was 0.6–1.6); slider divisions **37** (0.2× steps).
2. **Shared constants** in `speedcam_crt_geometry.dart`; `config_store` + settings import them.
3. **0106 path intact:** `forceFlutterViewSize`, overlay app `SizedBox.expand` + watch scale, successive `setLayout` — still live, not a no-op.
4. **Units:** geometry 5× footprint, clamp 0.6–8.0, migration identity, CRT fill at 2240×1643 slot, successive setLayout incl. 8.0.
5. **No Live bump** — stays **1.1.0+23**. Soft car T3. Did **not** implement 0115.

### Verification

`flutter test` — geometry + overlay size scale + 0079 layout + 0116 migration. `dart analyze` clean on touched Dart.

**Divergence:** None from scope. Soft: car T3 Maxim taste may retune max.



## ACCEPT (PDM 2026-09-26)

Tip `74edf87` (1.1.0+23; Live not bumped). QA T2 dens320 PASS (`tmp/qa/0116-cut-74edf87/`); four-point PASS (soft); units 17/17. Slider max **1.6→8.0** (5×): setLayout **336×246 / 896×657 / 4480×3285**; prefs 8.0 persist relaunch; 1.6 identity migrate (no remap); 0106 path intact. Soft: car T3 Maxim taste; Tablet canvas clips 8.0 to **2560×1480** (setLayout still 4480×3285). Live still **1.1.0+23**.

## Notes

- Tip OK; **no Live bump** until Maxim GO.
- Do **not** implement 0115 here.
