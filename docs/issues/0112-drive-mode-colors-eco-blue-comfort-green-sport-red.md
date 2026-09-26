---
status: open
labels: [hud, adapt, drive-mode, settings]
created: 2026-09-26
satisfies: Drive-mode accents match Maxim ECO blue → Comfort/standard green → Sport red; tip+config order matches
tier: T2
owner: zee-dev
blocked-by: []
modules: [DriveModeToastLayer, DriveModeCornerDot, BatteryConfig/ConfigStore, Settings help, tip docs]
priority: now
filed-by: zee-pdm
related: [0104, 0109, 0110]
parent: [0109]
gate: armed-2026-09-26
---

# 0112 — Drive-mode colors: ECO blue · Comfort green · Sport red (+ tip/config order)

## Block scope

Maxim 2026-09-26 ~13:09 Minsk HARD: driving-mode accents must be **ECO blue → standard/Comfort green → Sport red**, and the **same order** must appear in tip docs and config (enums, settings copy, help, reconciliation tables).

This **supersedes** the 0109/0110 color tables:

| Mode | Was (0109 toast / 0110 dot) | **Now (both toast + corner-dot)** |
|------|-----------------------------|-----------------------------------|
| ECO | green `#3DDC84` | **blue** (pick exact hex; document) |
| Comfort / standard | blue `#3B82F6` | **green** |
| Sport | toast red `#FF3B30` / dot yellow `#FFCC00` | **red** on **both** toast and persistent corner-dot (no yellow) |

## Product rules

1. Toast accents and corner-dot accents use the **same** ECO blue / Comfort green / Sport red palette.
2. Tip docs, ConfigStore / BatteryConfig enums or switch order, settings EN/RU strings, and Reconciliation tables list modes in **ECO → Comfort → Sport** (or explicit “standard = Comfort”) — not Comfort-first if that contradicts Maxim’s named order.
3. Simulated / Preview / inject recipe on T2 dens320 must show the new colors pixel-exact.
4. Live **not** bumped in this tip; ship only after Maxim GO.

## DoD (T2 dens320)

- [ ] Toast ECO blue / Comfort green / Sport red pixel-exact
- [ ] Corner-dot (0110 ON) same three colors; Sport ≠ yellow
- [ ] Tip + config + arb strings order/docs match ECO → Comfort → Sport
- [ ] Units / analyzer clean
- [ ] Soft: car T3

## Soft / residuals

- Sport **pulsate** is **0113** (depends on Sport being red here).
- Car T3 soft.
