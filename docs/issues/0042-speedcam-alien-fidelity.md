# 0042 — Alien CRT + audio fidelity

## Status
done @ 956d6b8 (T1 relay multi-cam PASS; taste polish landed through a6f3383/09e5f0e/448a300)

## Goal
Raise Alien look/sound toward Maxim’s motion-tracker refs (and taste), after 0041 Demo lands.

## Visual
- Maxim recut (2026-09-19): scan = **expanding circles from center** (not rotating sector); overall aesthetic + sound still need prop fidelity
- Blip brightens / thickens as range closes
- CRT grit / scanline / mild distortions (phosphor bloom ok)
- Scan = **forward circular sector** (front hemisphere), not a thin rotating sweep line
- Stay distinct from Default (text-only)

## Audio
- Motion-tracker ping closer to prop (rate vs range already in 0040; timbre/feel needs work)
- As range closes: **pitch climbs** into a light whistle (prop tracker), not just faster beeps
- Approach sting can stay; don’t make Default noisy

## DoD
- [x] Pixel A/B vs current Alien reads “closer to prop” at a glance (sector scan + range-linked blip weight)
- [x] Alien sound noticeably better / more authentic (QA + Maxim taste)
- [x] Default unchanged
- [x] Demo on HUD still exercises the improved Alien path
- [ ] T1 (+ T2 if warm) evidence

## Refs
`docs/knowledge/speedcam-alien-refs/`
