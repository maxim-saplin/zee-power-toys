# 0041 — Speedcam “Demo on HUD” from DHU settings

## Status
done @ 72e3025


## Goal
Maxim wants to preview looks + sounds on the live HUD **without driving / approaching a cam**. Today: DHU settings = look preview; HUD stays idle empty until real/FL approach.

Add a one-tap **Demo on HUD** on Speedcam settings that:
- forces an approach-state (or equivalent) on the live HUD window so **active look** paints (Default text-right or Alien CRT)
- triggers approach sting / Alien ping as configured
- clears / ends cleanly (no stuck danger)

## DoD
- [x] Button on Speedcam settings (DHU)
- [x] HUD shows active look without FL / polyline drive
- [x] Sound path exercises (sting; Alien ping if Alien + sound on)
- [x] Idle after demo ends (or explicit Stop)
- [ ] T1 runtime-confirmed (T2 if warm)

## Notes
0040 PASS @ ea20022. Idle-empty without demo remains correct product behavior.
