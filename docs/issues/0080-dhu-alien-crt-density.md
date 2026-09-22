---
status: cooking-fix
labels: [speedcam, hud, dhu, alien, visual, hard]
created: 2026-09-22
satisfies: Alien CRT on DHU preview/overlay reads like HUD windshield — bold lines, grit, distance overlapping radar
tier: T2
owner: zee-dev
blocked-by: []
modules: [SpeedcamRadarWidget, _AlienWedgePainter, speedcam settings preview, SpeedcamSystemOverlay]
priority: now
filed-by: zee-pdm
---

# 0080 — HARD: DHU Alien CRT density = HUD look (not thin-hair)

## Why (Maxim 2026-09-22)

0079 closed code-path / overlay layout. **Visual CRT density was not delivered.** Side-by-side photos:

- **DHU / settings preview** — thin strokes, sharp high-DPI “hair”, distance `0.20` + limit sit cleanly in corner, little grit/bloom. Ref: `docs/knowledge/speedcam-alien-refs/0080-dhu-vs-hud/dhu-thin.png`
- **HUD windshield** — bold lines, CRT/scanline grit, large distance `0.46` **overlapping** the fan, phosphor glow. Ref: `docs/knowledge/speedcam-alien-refs/0080-dhu-vs-hud/hud-crt.png`

Maxim: HUD looks better because lower DPI; he wants the **same CRT/distorted look on DHU**, not a skinny vector redraw.

## Likely cause (hypothesis — verify)

`_AlienWedgePainter` uses **fixed logical** `strokeWidth` (~1.1–3.2), scanline step `2.0`, grit `1.1`, readout `fontSize` 22/12 — good relative size on small HUD widget, **thin/haired** when the same paint runs in a larger sharp DHU preview disk.

## Block scope

Make Alien paint **scale with paint size** (or otherwise density-match) so DHU settings preview + system overlay Alien read as the same CRT aesthetic as HUD at a glance: bolder strokes, visible scan/grit, distance readout large and overlapping the fan like the windshield photo.

## DoD

- [ ] Side-by-side: DHU Alien preview vs HUD Alien — Maxim/PDM says “same CRT vibe” (bold + grit + overlap), not “same code path”
- [ ] Distance km readout overlaps fan the way HUD does (not tucked hairline corner text)
- [ ] Overlay Alien (when ON) matches the same density
- [ ] Default look unchanged
- [ ] QA FINDINGS with pixel A/B + PDM ACCEPT (double-check against Maxim’s refs)

## Out of scope

- Reopening Windshield cam harvest
- Changing radarLook modes / sound
- Live `src/` YNavi cutover

## Notes

PDM owned the miss: 0079 ACCEPT covered layout/wiring, not this visual bar. Treat as product HARD until pixels match.

## Fix pass (Maxim FAIL — clip + km)
- Dropped outer settings `ClipRRect` (shaved CRT/fan)
- Km + limit bottom-left of full composite after CRT restore (HUD geometry; not mid-left)
