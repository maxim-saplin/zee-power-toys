# 0040 — Speedcam radar dual look: Default + Alien

## Status
in-progress

## Goal
Two distinct radar looks, switchable in Speedcam settings (and visible on HUD + DHU):

1. **Default** — HUD-right when approaching a cam: **direction + distance only** (minimal, no CRT/wedge/dots). Sound alert on approach (0035). **Nothing shown** when no cams in range / on course. Quiet — no motion-tracker ping loop.
2. **Alien** — fun mode: greenish CRT **front hemisphere** with pulses + dots (Maxim’s motion-tracker refs). Authentic Alien motion-tracker sounds (range-tightening ping + approach sting).

Current single CRT is Alien-ish but not prop-faithful and must not stay as the only look.

## Refs
Maxim refs (2026-09-19): `docs/knowledge/speedcam-alien-refs/` (motion tracker screenshots).

## DoD
- [x] Config: `radarLook` (or equivalent) — `default` | `alien`; persisted; DHU segmented control / switch
- [x] **Default** and **Alien** read as different at a glance (HUD clean vs wedge/CRT/blip)
- [x] Both looks render on HUD compact + DHU large; fit rules from 0039 still hold
- [x] Alien: range-linked ping rate (closer → faster); respects sound enable; Default stays quiet/minimal on the loop
- [x] FL/dump exposes active look for QA
- [ ] T1 (+ T2 if warm) pixel A/B evidence; QA keys for which look is active

## Out of scope
- Full prop chrome 1:1 replica (bezel LEDs optional polish)
- New cam data / proximity math (reuse 0032/0038)
