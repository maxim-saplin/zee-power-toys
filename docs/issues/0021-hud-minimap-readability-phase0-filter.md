---
status: done
labels: [hud, minimap, filter, readability]
created: 2026-06-12
closed: 2026-06-12
satisfies: HUD · Minimap — readable emissive rendering as the default
blocked-by: []
modules: [HudHost, MinimapHost]
tier: T2
---

# 0021 — HUD minimap readability (phase0 parametric filter + readable defaults)

## Block scope

Block 0019 landed real YNavi cluster map pixels on the HUD surface — but the result was a
**near-solid yellow wash** (confirmed in `shots/redo/t2-ynavi-map.png` before this fix).  Only
a faint "Kuzmy Chornaga St" label and a faint route line survived.  That is not a readable HUD.

This Block corrects the root causes and makes the map **readable by default**:

- Pure-black emissive background
- Bright neon green-yellow road lines
- Multiple street labels clearly readable (both Latin and Cyrillic)
- No user action required to enable readability (Principle 1)

## Root causes (three, chained)

### 1. `setLayerType` applied on TextureView directly (does NOT filter SurfaceTexture content)

`MinimapView.applyHardwareLayerFilter()` called `setLayerType(LAYER_TYPE_HARDWARE, paint)` on
`this` (the `TextureView` itself).  Per Android internals and confirmed in
`docs/knowledge/hud-presentation-host.md §7`:

> *"applying `setLayerType` directly on a TextureView does NOT filter SurfaceTexture content;
>  the parent ViewGroup's layer captures the composited pixels."*

YNavi's EGL renderer writes directly into the SurfaceTexture's GL buffer.  A hardware layer
on the TextureView itself is re-created by the view system when the TextureView gets a GL
context — not by the EGL producer.  The filter was effectively never applied to YNavi's pixels.

**Fix:** wrap `MinimapView` in a `filterWrapper` `FrameLayout`; apply
`filterWrapper.setLayerType(LAYER_TYPE_HARDWARE, createHudFilterPaint())`.

### 2. `onSurfaceTextureUpdated` was empty — hardware layer never invalidated

With a hardware layer on the `filterWrapper`, Android caches the composited output.  When
YNavi pushes a new frame to the SurfaceTexture, the `View` invalidation system is NOT
triggered — the cached layer goes stale and the map freezes or shows the last pre-filter frame.

**Fix:** `onSurfaceTextureUpdated` now calls `filterWrapper?.invalidate()`, forcing the
hardware layer to re-render each new YNavi frame.

### 3. YNavi was rendering in DAY mode — bright map + any tint = yellow wash

The previous `performHandshake` passed `context.resources.configuration` (day/light mode) to
`onAppCreate`.  YNavi's day map has a bright white background.  Any linear colour-matrix tint
applied on top of white-background pixels produces a uniformly bright, washed-out result.

**Fix:** `YNaviCarAppHost.performHandshake` now builds a night-mode `Configuration`
(`UI_MODE_NIGHT_YES`) and passes it to `onAppCreate`, then re-sends it via
`onConfigurationChanged` after `onAppResume` — exactly matching phase0's pattern.

## The fix — three changes

### A. `filterWrapper` pattern in `setupHud()` (`MainActivity.kt`)

```kotlin
// BEFORE (wrong — TextureView direct filter):
root.addView(mm, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))

// AFTER (correct — wrapper carries the hardware layer):
val filterWrapper = FrameLayout(pres.context)
filterWrapper.addView(mm, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
mm.filterWrapper = filterWrapper
filterWrapper.setLayerType(View.LAYER_TYPE_HARDWARE, createHudFilterPaint())
root.addView(filterWrapper, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
```

### B. `createHudFilterPaint()` — parametric ColorMatrix (ported from phase0)

Replaces the static 4×5 matrix.  Defaults:

| Parameter | Value | Effect |
|-----------|-------|--------|
| contrast | 3.0 | Boosts bright features 3× |
| threshold | 150 | Pixels < ~150/255 → BLACK (map bg → dark emissive) |
| preset | 0 (green-yellow) | tR=0.7, tG=1.0, tB=0.1 |
| saturation | 0 | Fully monochrome-tinted (no colour bleed) |
| brightness | −20 | Small negative offset |
| huePass | 1.0 | Keep green/yellow features in colour |
| hueAngle | 120° | Green channel passes through full contrast |
| invert | false | — |

### C. Night mode in `YNaviCarAppHost.performHandshake()` (`YNaviCarAppHost.kt`)

```kotlin
val nightConfig = Configuration(context.resources.configuration).apply {
    uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or UI_MODE_NIGHT_YES
}
target.onAppCreate(carHostStub, appIntent, nightConfig, cb)
// ... onAppStart, onAppResume ...
target.onConfigurationChanged(nightConfig, cb)   // re-deliver after resume
```

### D. `setDefaultBufferSize` zoom-out (`startYNaviOnSurfaceReady`)

`surface.setDefaultBufferSize(width * 2, height * 2)` tells YNavi to render at 2× the view
dimensions.  The compositor scales it back down to the viewport, showing 2× more map area
(minimapScale = 0.5, matching phase0 §6).  Confirmed in logcat:
`startYNaviOnSurfaceReady: w=1280 h=720 buf=2560x1440 dpi=213`.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md).

- [x] Runtime-confirmed on **T2** — artifact: `shots/redo/t2-ynavi-map.png`.
      Screenshot shows: pure-black background; bright neon green-yellow roads; readable labels
      (Kropotkinskaya, Pushkin Museum, ул. Остоженка, Church of Saint Elijah the Prophet);
      route direction arrows; metro station icon.
- [x] Phase0 reference captured: `shots/redo/t2-ynavi-map-phase0-reference.png` (Moscow
      Tverskaya area; White preset; dark bg, natural night-mode yellow roads; all labels
      readable). Our result matches the readability bar.
- [x] `flutter analyze` clean (0 issues).
- [x] `flutter test` green: **199 tests** (no regression).
- [x] Debug APK builds successfully.
- [x] A/B testing doc written: `docs/knowledge/phase0-ynavi-ab-testing.md`.
- [x] Block 0019 reconciled (readability failure noted; this Block is the corrective fix).
- [x] `BACKLOG.md` updated.

## Reconciliation

### Block 0019 honest reconciliation

Block 0019 closed with `shots/redo/t2-ynavi-map.png` showing a **yellow wash** — map pixels
were present (the render pipeline worked) but the image was unreadable.  The DoD said "actual
map tiles" but did not specify readability as a criterion; this was an oversight.  This Block
corrects that gap and updates the DoD retroactively:

> *Block 0019 artifact existed but failed the readability bar. Block 0021 is the corrective.*

The root cause was not in the `parkForYNavi` / `onSurfaceTextureAvailable` handshake (those
were fixed correctly in 0019), but in the colour-filter layer applied after the map was
rendering.

### `docs/knowledge/hud-presentation-host.md` — no changes needed

§7 already documented the correct filter values and the mandatory wrapper pattern.  The code
now matches the doc.

## Notes

- The `applyHardwareLayerFilter()` method on `MinimapView` was **removed** (was applying the
  filter on the TextureView — the root bug).
- `MinimapView.onSurfaceTextureUpdated` was previously empty; it now calls
  `filterWrapper?.invalidate()`.
- The placeholder render loop now calls `filterWrapper?.postInvalidate()` after each
  `unlockCanvasAndPost` so the hardware layer stays current during the animated fallback.
- `MinimapView.isOpaque` changed from `true` to `false` (matching phase0 pattern; isOpaque on a
  TextureView inside a hardware-layer parent does not affect the filter).
- For T3 on-car validation, use the A/B protocol in `docs/knowledge/phase0-ynavi-ab-testing.md`
  to compare against the phase0 reference at the actual HUD optics.
