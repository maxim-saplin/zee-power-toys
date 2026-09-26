---
status: open
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

- [ ] Slider max visibly ~5× prior max footprint (measure HUD secondary / Flutter size)
- [ ] Mid and min still usable; prefs migrate sanely
- [ ] Soft: car T3 confirm “proper dimensions” — Maxim taste gate

## Soft / residuals

- Exact max number left to measure on Tablet + Maxim car taste; tip documents chosen factor.
