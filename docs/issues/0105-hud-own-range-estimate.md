---
status: ready-for-agent
labels: [hud, battery, range, adapt]
created: 2026-09-25
satisfies: foundation
blocked-by: []
modules: [AdaptApiCarSignals, CarSignals, BatteryWidget / HUD battery line, settings]
tier: T2
owner:
priority: now
filed-by: zee-pdm
gate: armed-2026-09-25
parent: []
---

# 0105 — Own estimated range beside battery % (toggle + plain “how”)

## Block scope
Maxim 2026-09-25: **do not** trust the car’s Adapt range as the HUD primary (too optimistic). Show a **togglable own estimated range** in the **same line as battery percentage**. Agents must **design and verify a useful estimator** (not a placeholder). The settings toggle needs a **simple ruler / hint** that explains **how the estimate is calculated** in plain words.

## Product rules (HARD)
1. **Primary HUD figure = our estimate**, never Adapt `0x00100800` / `0x00101900` as the main number (those may appear in Diagnostics only if useful).
2. **Toggle** (default OFF or ON — pick and document; prefer OFF until estimate has enough history, or show “—” / hide until ready).
3. When ON and estimate ready: battery line like `72% · ~180 km` (soft tilde; no false precision).
4. **Settings copy:** short **ruler / help under the toggle** explaining the formula in everyday language (EN + RU). Example tone: “Uses recent power use over distance you drove. Needs a few kilometres before it shows.” Exact wording follows the chosen algorithm.
5. Degrade cleanly: Simulated / no history / parked cold-open → no fake km; HUD must not jump wildly.

## Estimator — agents invent something useful
**Open design** for zee-dev (+ early zee-dev-beta): propose and implement one estimator that is **honest and useful on DHU**, then prove it on T2 / note T3 caveats.

Candidates to evaluate (pick / combine; document choice in Reconciliation):
- Rolling consumption from Adapt efficiency `0x00103100` when non-sentinel, else SoCΔ over GPS/odometer distance
- EWMA / last-N-km window; ignore idle / charging intervals
- Floor/ceil and max step-per-minute so HUD does not thrash
- Persist window across process death (prefs) so a short stop does not wipe history

**Out of scope:** claiming better-than-OEM accuracy; trip planning; navigation ETA.

## Adapt / existing surfaces
- Already live in Toys: SoC / temp / charge / power-flow — `AdaptApiCarSignals`, `CarSignals`, battery HUD.
- Available but unused (reference only, not HUD primary): range total `0x00100800`, range EV `0x00101900`, efficiency `0x00103100` — see Adapt survey 2026-09-25 / `docs/knowledge/car-signals-adaptapi.md`.

## Definition of Done
- [ ] Written estimator design in Reconciliation (inputs, window, units, when hidden)
- [ ] Toggle in settings (EN/RU) with **plain-language how-it-is-calculated** help under the control
- [ ] HUD battery line shows estimate when toggle ON and estimate ready; hidden/soft when not
- [ ] Units / Simulated fixtures for: no-history → no km; after seeded trip → ~km appears; toggle OFF hides
- [ ] T2 Tablet dens 320 evidence — `tmp/qa/0105-cut-<sha>/` (settings chrome + HUD battery line)
- [ ] Soft note if car T3 live tune still owed
- [ ] Beta four-point; PDM ACCEPT after own check

## Notes
- Prefer shipping **0105 before or with 0104**; one Tablet — no parallel emu.
- Live bump only on Maxim GO after ACCEPT.
