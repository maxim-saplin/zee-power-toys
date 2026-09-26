---
status: ready-for-agent
labels: [adapt, spike, power, investigate]
created: 2026-09-26
satisfies: foundation
blocked-by: []
modules: [AdaptApiCarSignals, PowerMagnitudeProbe / zee_hud_2 diagnostics, CarSignals]
tier: T3
owner: zee-dev-beta
priority: parallel
filed-by: zee-pdm
gate: armed-2026-09-26
related: []
---

# 0111 — Spike: instant drive/regen power magnitude (cluster bar)

## Why

Maxim 2026-09-26: many past attempts failed to find a live Adapt signal for **how much power the car consumes while accelerating** or **regenerates while braking**. Cluster shows a power/regen bar; Toys only has **Power Flow state** (drive / regen / standstill enum via `0x24010100`) — not a usable **kW / % magnitude** for HUD tacho animation or other product uses. Assign **zee-dev-beta** (parallel; do not steal Tablet from **0109/0110**).

## What we already know (do not re-discover blindly)

From `docs/knowledge/car-signals-adaptapi.md` + `zee_hud_2` PowerMagnitudeProbe / EnergyProbe:

| Have | Missing |
|------|---------|
| Power Flow **enum** `0x24010100` (drive/regen/standstill) — live in Toys | Instant **discharge / regen magnitude** (kW or 0–100 bar) while driving |
| Charge power `0x2420C000` — live **only while charging** | Same figure while driving |
| Dead (always 255): Discharge Power Actual `0x00103600`, Regen Bar A/B `0x24215C00` / `0x241E5000`, Discharge Limit `0x00103500`, legacy charge power `0x241E0500` | — |

AAOS `CarProperty` path is confirmed dead on DHU. Prefer Adapt reflection + on-car dump.

## Spike questions (answer all)

1. **Catalog sweep:** which Adapt ISensor / ICarFunction / customize IDs could plausibly be “instant power % / kW / motor torque / current while driving”? Cite prior probe logs and any new IDs from fresh T3 dump.
2. **Reproduce dead list:** confirm Regen Bar A/B + Discharge Power Actual still sentinel on this car firmware (short drive + brake regen).
3. **Indirect proxies:** can we derive a usable proxy (e.g. pack current × voltage, motor RPM×torque, SoC slope) that tracks the cluster bar within ~±20% on accel/regen? If yes, document formula + error; if no, say why.
4. **Product fit:** if a live magnitude exists (or a good proxy), propose one HUD use (tacho-style bar / numeric kW) vs “park for later”.
5. **Verdict (one sentence):** found live ID / workable proxy / **dead-end for now** — with evidence paths.

## Out of scope

- Implementing HUD tacho UI in this Block (file a follow-on only after verdict = found).
- Blocking **0109** / **0110** (drive-mode toast/dot) — those keep the Tablet.
- Charging-only power (already shipped).

## Definition of Done

- [ ] FINDINGS markdown under `docs/spikes/instant-power-magnitude/` (or `tmp/qa/0111-instant-power/`) with tables: IDs tried, values while accel / regen / standstill, sentinel notes.
- [ ] Update `docs/knowledge/car-signals-adaptapi.md` if anything new (live ID, confirmed dead, or proxy recipe).
- [ ] Plain-English verdict for Maxim + PDM.
- [ ] PDM ACCEPT on verdict (no Live bump from this spike).

## Notes

- Needs **car T3** (or prior on-car dumps if Maxim already has logs) — Tablet cannot invent Adapt magnitude.
- Soft: if car session unavailable, bank “blocked waiting T3” with a proposed dump script for next drive.
- Engage Maxim only for LOOK / car session, not for QA rubber-stamp.
