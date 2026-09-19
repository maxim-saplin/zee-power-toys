# 0039 — DHU Speedcam radar fits vertically (no scroll for disk)

## Status
done @ 12f8584


## Goal
On Speedcam settings, the large Alien/CRT radar must be fully visible without scrolling. Today it is `AspectRatio(1)` under harvest/DB, so on typical T1/DHU heights the square overflows and the disk is half off-screen.

## DoD
- [x] Radar disk (`dhu-speedcam-radar`) fully on-screen at T1 ~800×600 and DHU-ish heights without scrolling to see the bottom of the CRT
- [x] HUD/sound toggles + range slider remain usable; harvest/DB may still scroll below if needed
- [x] Alien/CRT look unchanged (no theme switch in this Block — Alien is the only look)
- [ ] T1 runtime-confirmed (QA screenshot)

## Notes
Maxim (2026-09-19): radar requires scrolling; must fit vertically. Theme switch asked — answer: no switch; Alien is the product look (REQUIREMENTS bonus Alien mode).
