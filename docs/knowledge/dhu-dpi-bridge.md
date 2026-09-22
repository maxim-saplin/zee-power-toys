# DHU reported vs actual DPI (0080)

## Hardware (Maxim 2026-09-22)
- Panel: **15.05"** diagonal, **2.5k** (~2560×1600)
- Physical diagonal px: √(2560²+1600²) ≈ **3018.9**
- **Actual DPI** ≈ 3018.9 / 15.05 ≈ **200.6**
- Android **reports** ~**160** dpi (dpr ≈ 1.0 on that framebuffer)

## Product lock
- **HUD Alien CRT is gold** — windshield look must not regress.
- DHU settings / overlay Alien must **match HUD gold**, using a real↔reported bridge — not packing hacks.

## Bridge
`dhuDpiBridge = actualDpi / reportedDpi ≈ 200.6 / 160 ≈ 1.254`

When Flutter `devicePixelRatio` is the *reported* low value on automotive geometry
(`dpr < 2` ∧ logical width ≥ 1600, same heuristic as `dhuSmartScale`), scale Alien
phosphor strokes by `dhuDpiBridge` so physical weight tracks HUD gold.

On HUD Presentation (`~1024×576`, dpr≈1, not automotive-wide): bridge = **1.0**
(identity) — gold path unchanged.

## T1 Mac honesty
Mac Retina host dpr is ≥ 2, so the automotive gate never fires on raw
`View` metrics. `DhuScaledLayout` letterboxes the design framebuffer
(2560×1600 @ reported dpr 1.0) into the DHU window and publishes
`DhuSurfaceMetrics` so Alien CRT uses bridge ≈ 1.254. The HUD isolate
has no metrics → identity (gold). Side-by-side Mac windows are then a
real DPI A/B that predicts car.

