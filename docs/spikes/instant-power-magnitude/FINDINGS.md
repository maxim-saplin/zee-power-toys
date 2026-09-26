---
spike: 0111-instant-power-magnitude
agent: zee-dev-beta
date: 2026-09-26
status: complete (prior on-car dumps; no fresh T3 this run)
car_session: none (Tablet reserved for 0109/0110)
primary_evidence: ~/src/zee_hud_2/logs/phase0/oncar/2026-02-23_run-01/ + docs/30_1…30_8
---

# 0111 Spike FINDINGS — Instant drive/regen power magnitude

## Plain-English verdict (Maxim / PDM)

**Dead-end for now:** no live Adapt ID gives instant drive/regen kW or cluster-bar %, and no validated ±20% proxy exists; keep shipping Power Flow **state** only and park a tacho bar until a future firmware bridges magnitude (or a calibrated synthetic is deliberately accepted as approximate UX).

## Answers to spike questions

### 1) Catalog sweep — plausible Adapt IDs

Sources: `PowerMagnitudeProbe.kt` candidate maps, `CarApiCatalog.kt`, `docs/research/ADAPTAPI_ID_DICTIONARY.md`, campaigns `30_1`–`30_8`.

| Role | ID | API | Prior result |
|------|-----|-----|--------------|
| Discharge power actual (named kW) | `0x00103600` | ISensor float | Always **255**, 0 callbacks |
| Discharge limit | `0x00103500` | ISensor float | Always **255**, 0 callbacks |
| Regen Bar A | `0x24215C00` | ICarFunction int/float | Always **255** / Float.MIN_VALUE |
| Regen Bar B (`CHARGING_REGENERATION_MODE_BAR`) | `0x241E5000` | ICarFunction | Always **255** |
| Charge power live | `0x2420C000` | customize float ZONE_GLOBAL | Live **only while charging** (20–61 kW); **0 / sentinel while driving** |
| Charge power legacy | `0x241E0500` | function | Always 255 |
| Charge V / A | `0x24140100` / `0x24140200` | customize float | Live only while charging |
| Power Flow **state** | `0x24010100` | getFunctionValue | **LIVE enum** (drive/regen/standstill) — not magnitude |
| Power Flow HEV | `0x24010200` | function | 255 |
| Energy regen mode | `0x20020500` | function | Returns own-ID-ish enum (mode, not kW) |
| E-Pedal | `0x20180100` | function | 0 static in tested windows |
| Charge/Discharge sts | `0x241D2500` | function | 255 |
| Hybrid SoC | `0x24010500` | function | 255 |
| Aux DCDC “power” 1/2 | `0x00103300` / `0x00103400` | ISensor | Live but **aux** (~14.8 V / slow load drift); not traction |
| Trip energy cons 1/2 | `0x00103100` / `0x00103200` | ISensor | Slow trip averages (~16 s), not instant bar |
| Misc charge-family (dictionary) | `0x240E0A00`, `0x24120100`/`0200`, `0x24150100`/`0200`, `0x241E5100`, … | function | Sentinel/static in 30_1 short sweeps |
| AAOS EV charge rate / speed | CarProperty | VHAL | Frozen / never updated on Aptiv DHU |
| Direct CAN | `/dev/can*` | — | Not present in Android VM |

**New IDs this spike:** none (no fresh T3 dump). Catalog above is the full plausible set already exercised on-car.

### 2) Dead list reproduce (prior dump citation)

Confirmed across **parked + drive** windows on firmware fingerprint `aptiv/zeekr_dhu… eng.buildf.20251210…` (2026-02-23 session). Motion anchors prove real accel/brake during the same sweeps.

| ID | Label | Parked (`s2_parked_sweep_baseline.json`) | Drive (`s2_drive_sweep.json` / `c1_motion_timeseries_sweep.json`) | Sentinel |
|----|-------|------------------------------------------|---------------------------------------------------------------------|----------|
| `0x24215C00` | regen_bar_a | int **255** | int **255**, float MIN, 0 changes | yes |
| `0x241E5000` | regen_bar_b | int **255** | int **255**, float MIN, 0 changes | yes |
| `0x00103600` | discharge_power_actual | sweep min=max=**255**, 0 ch | min=max=**255**, 0 ch; **0 callbacks** after ISensorListener fix | yes |
| `0x00103500` | discharge_limit | **255** | **255**, 0 callbacks | yes |
| `0x2420C000` | charge power v2 | float_zG **0** (not charging) | float_zG **0** while driving | N/A drive |
| `0x24010100` | power_flow | int **0** (parked) | live enums (see § accel/regen) | **live state** |

Evidence paths:
- `~/src/zee_hud_2/logs/phase0/oncar/2026-02-23_run-01/s2_parked_sweep_baseline.json`
- `~/src/zee_hud_2/logs/phase0/oncar/2026-02-23_run-01/s2_drive_sweep.json` (anchors: speed_ch=114, accel_ch=117, brake_ch=31)
- `~/src/zee_hud_2/logs/phase0/oncar/2026-02-23_run-01/c1_motion_timeseries_sweep.json` (accel/brake motion_series + power_flow listener events)
- `~/src/zee_hud_2/logs/phase0/oncar/2026-02-23_run-01/s5_decision.txt`
- `~/src/zee_hud_2/docs/30_1_INSTANT_POWER_SIGNAL_REPORT.md` (regen bars 255 in run-06)
- `~/src/zee_hud_2/docs/30_8_POWER_FLOAT_LISTENER_REPORT.md` (Branch C)

**Fresh T3 reconfirm:** optional if firmware OTA since 2025-12-10 build; see `DUMP-SCRIPT.md`. Not required to close this spike given multi-window prior dumps.

### 3) Indirect proxies — workable within ~±20% of cluster bar?

| Proxy idea | Inputs available? | Why not ±20% today |
|------------|-------------------|--------------------|
| Pack I × V | **No** pack current/voltage while driving (charge V/A only when plugged) | Cannot form electrical power |
| Motor RPM × torque | **No** Adapt motor torque / RPM IDs found live | Missing both factors |
| SoC slope × pack Wh | SoC updates ~16 s; energy_cons is trip-average | Far too slow / lagged vs cluster bar |
| Accel% × speed (C1 synthetic) | Yes — `0x00101400`, `0x00100100` highly dynamic | Directional only; no regen precision from brake%; **never calibrated** against cluster; prior reports explicitly call it approximate, not ±20% validated |
| DCDC / energy_cons | Live but aux / trip | 0–3 changes vs 100+ motion changes in same 60 s |

**Conclusion:** no workable ±20% proxy without a new calibration campaign against the cluster (out of scope; would still be UX-fake, not true kW).

### 4) Product fit

- **Ship today:** Power Flow **state** arrow / color (`0x24010100`) — already in Toys.
- **Do not ship:** tacho-style magnitude bar or numeric drive kW (would be fake or stuck).
- **Park for later:** magnitude HUD until (a) firmware exposes a live ID, or (b) product explicitly accepts an uncalibrated synthetic as “feel” only (file follow-on then).
- Charging kW widget remains separate and already solvable via `0x2420C000`.

### 5) One-sentence verdict

**Dead-end for now** — Regen Bar A/B + Discharge Power Actual stay sentinel 255 through accel/regen/standstill windows in `zee_hud_2` 2026-02-23 dumps (`s2_*`, `c1_motion_*`, `s5_decision.txt`); no pack I×V / torque channel; synthetic accel×speed unvalidated for ±20%.

---

## Tables — values by window

### A) Named magnitude / bar candidates

| ID | Accel-rich drive | Regen/brake-rich drive | Standstill / parked | Notes |
|----|------------------|------------------------|---------------------|-------|
| `0x00103600` | 255 | 255 | 255 | 0 sensor callbacks |
| `0x00103500` | 255 | 255 | 255 | same |
| `0x24215C00` | 255 | 255 | 255 | float MIN |
| `0x241E5000` | 255 | 255 | 255 | float MIN |
| `0x2420C000` | 0 (zG) | 0 (zG) | 0 / charge-only live | Not traction |

### B) Power Flow state (live) during `c1_motion` listener window

Offsets from base `604045568`:

| Enum value | Offset | Meaning (knowledge) | Event count |
|------------|--------|---------------------|-------------|
| 604045587 | +19 | REAR_ELE_DRIVE | 12 |
| 604045588 | +20 | STANDSTILL | 11 |
| 604045589 | +21 | REGEN | 2 |
| 604045590 | +22 | REGEN_FRONT | 9 |
| 604045591 | +23 | REGEN_AWD | 2 |

Motion series same file: speed 0.28–14.2 m/s, accel pedal 0–19%, brake 0–12%; ≥5 accel-rich and ≥6 brake-rich samples — cluster bar would have moved; Adapt magnitude IDs did not.

### C) Slow/aux (rejected as traction magnitude)

| ID | Drive range (examples) | Changes / 60 s | Identity |
|----|------------------------|----------------|----------|
| `0x00103300` | ~14.4–14.9 | 0–1 | 12 V DCDC voltage |
| `0x00103400` | ~5–25 | 2–4 | aux load-ish |
| `0x00103100` | ~81–87 | 2–4 | trip kWh/100 km |
| `0x00103200` | ~0.1–6 | 1–4 | secondary energy metric |

---

## Architecture bound (why)

From `s5_decision.txt` / `30_8`: Aptiv Android VM gets a **selective** AdaptAPI bridge. Charging V/I/P prove the float+watcher path works (~2 Hz). Traction magnitude that feeds the cluster gauge is **not** among the bridged signals; AAOS VHAL and SocketCAN are dead ends on this DHU.

---

## Optional next-drive dump

See `DUMP-SCRIPT.md` in this folder — poll dead list + power_flow + motion anchors across accel / regen / standstill. Soft: only needed if firmware changed since build `20251210`.
