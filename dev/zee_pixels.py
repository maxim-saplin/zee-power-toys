#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10.0"]
# ///
"""zee_pixels.py — pixel-level comparison primitive for zee-power-toys.

Why this exists (see docs/knowledge/phase0-ynavi-ab-testing.md:110-115 for the
existing Pillow-based crop/compare pattern this generalizes): 26 delivery
Blocks were signed off as "runtime-confirmed with an attached screenshot", and
the app was still visibly broken on first human use. The gate accepted
*existence* proofs (a PNG exists, dimensions match) but never *comparison*
proofs (this frame differs/matches that one; this region has detail, that one
doesn't). This module is the comparison primitive: pure functions over Pillow
Images, no I/O beyond load/save, no VM-service or adb dependency at all — that
keeps it reusable from both the CLI driver (zee_diff.py) and ad-hoc scripts.

Deliberately NOT a dependency of dev/feedback_loop.py — that module is the hot
capture path and stays stdlib + websockets only (see its header). This module
is imported by dev/zee_diff.py instead, which already carries a Pillow dep.

Concrete motivating regression (Block 0021 -> Block 0025): the HUD minimap
filter was tuned for readability at full-bleed 1280x720, then correctly
confined to a 210x210 Safe-Area square — which silently destroyed readability
because the map still renders at the wide-area zoom level. Both Blocks passed
their (existence-only) runtime-confirmation gate. See:
  shots/redo/t2-hud-final-readable.png     (good — readable detail)
  shots/redo/t2-hud-minimap-confined.png   (regression — green mush)
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageFilter

# ---------------------------------------------------------------------------
# Thresholds used by `metrics()` — named so `compare()`/callers can reuse them.
# ---------------------------------------------------------------------------
INK_LUMA_THRESHOLD = 24     # > this luma counts as "lit" for inkFrac
BLACK_LUMA_THRESHOLD = 8    # < this luma counts as "emissive black" for blackFrac
EDGE_THRESHOLD = 40         # FIND_EDGES response > this counts toward edgeDensity

# colorGlowFrac thresholds (see metrics() docstring): a pixel counts as "color
# glow" when its luma is low enough to read as roughly-off at a glance, but
# some individual channel is bright enough that on a real additive-RGB
# emissive display it is genuinely emitting light — the class of defect
# perceptual-luma blackFrac structurally cannot see (blue has a luma weight
# of only 0.11, so a saturated navy pixel can sit well under a luma ceiling
# while its B channel is near-saturated).
COLOR_GLOW_LUMA_CEILING = 40     # luma <= this reads as "should be off"
COLOR_GLOW_CHANNEL_FLOOR = 60    # ...yet some channel is >= this: it is not off


def load(path: str) -> Image.Image:
    """Load an image from [path] and return it as RGB (drops alpha/palette)."""
    return Image.open(path).convert("RGB")


def crop_roi(img: Image.Image, roi: tuple[int, int, int, int]) -> Image.Image:
    """Crop [img] to (x, y, w, h) -> [x, y, x+w, y+h] (PIL box form)."""
    x, y, w, h = roi
    return img.crop((x, y, x + w, y + h))


def _luma_channel(img: Image.Image) -> Image.Image:
    """Return the L (luma) channel of [img]."""
    return img.convert("L")


def metrics(img: Image.Image) -> dict[str, Any]:
    """Compute readability/content metrics for [img].

    - inkFrac:      fraction of pixels with luma > INK_LUMA_THRESHOLD.
                     Catches "shows nothing" (a blank/near-black frame).
    - edgeDensity:  FIND_EDGES on the L channel, fraction of pixels with
                     response > EDGE_THRESHOLD. Catches "green mush" — this is
                     a detail-per-area measure, not a brightness measure, so a
                     frame that is uniformly bright-green but featureless
                     still scores low here even though inkFrac is high.
    - distinctLuma: count of distinct luma (0..255) values present. A cheap
                     proxy for "how much visual information survived" —
                     collapses toward a handful of values when detail is lost
                     to over-aggressive filtering/scaling.
    - blackFrac:    fraction of pixels with luma < BLACK_LUMA_THRESHOLD. The
                     "emissive-black" check: on a HUD combiner/projector, a
                     black pixel emits no light, so "is this region truly
                     black" is a real product question (distinct from mere
                     darkness) — e.g. confirming a Safe-Area surround is
                     actually non-emissive rather than dark-gray bleed.
    - meanLuma:     mean luma across the image.
    - colorGlowFrac: fraction of pixels that are luma-dim (<= COLOR_GLOW_LUMA_
                     CEILING) yet have some channel >= COLOR_GLOW_CHANNEL_FLOOR
                     — real per-channel light emitted from a pixel that reads
                     as "basically off" under perceptual luma. blackFrac is
                     blind to this class of defect by construction: it only
                     asks "is luma low", and luma weights blue at 0.11, so a
                     saturated-but-dim navy background (CONTEXT.md's forbidden
                     "faint glow on the windshield") can score a comfortably
                     low luma while still emitting real light. Caught in
                     practice: a HUD minimap filter measured blackFrac=0.72
                     and looked "mostly dark" by that number alone, but was a
                     visibly glowing navy field — huePass 0.0->1.0 on the same
                     frame moved blackFrac by lessthan 0.01 despite the two
                     images being a plain grayscale render vs. an obviously
                     colored one. Use this alongside blackFrac, not instead of
                     it: blackFrac catches "not dark", colorGlowFrac catches
                     "dark-looking but still lit".
    """
    l_img = _luma_channel(img)
    hist = l_img.histogram()  # 256 buckets, luma 0..255
    total = sum(hist)
    if total == 0:
        return {
            "inkFrac": 0.0, "edgeDensity": 0.0, "distinctLuma": 0,
            "blackFrac": 0.0, "meanLuma": 0.0, "colorGlowFrac": 0.0,
        }

    ink_count = sum(hist[INK_LUMA_THRESHOLD + 1:])
    black_count = sum(hist[:BLACK_LUMA_THRESHOLD])
    distinct_luma = sum(1 for c in hist if c > 0)
    mean_luma = sum(i * c for i, c in enumerate(hist)) / total

    edges = l_img.filter(ImageFilter.FIND_EDGES)
    edge_hist = edges.histogram()
    edge_total = sum(edge_hist)
    edge_count = sum(edge_hist[EDGE_THRESHOLD + 1:])
    edge_density = (edge_count / edge_total) if edge_total else 0.0

    # colorGlowFrac: per-pixel AND of two binary masks via 0/255 multiply
    # (PIL 'L'-mode ImageChops.multiply divides by 255, so 255*255->255,
    # anything*0->0 — an exact AND for two 0/255 masks), avoiding a raw
    # Python per-pixel loop while still asking a genuinely per-pixel
    # (not per-channel-independently) question.
    r, g, b = img.split()
    max_channel = ImageChops.lighter(ImageChops.lighter(r, g), b)
    bright_mask = max_channel.point(lambda p: 255 if p >= COLOR_GLOW_CHANNEL_FLOOR else 0)
    dim_mask = l_img.point(lambda p: 255 if p <= COLOR_GLOW_LUMA_CEILING else 0)
    glow_mask = ImageChops.multiply(bright_mask, dim_mask)
    glow_count = sum(c for i, c in enumerate(glow_mask.histogram()) if i >= 128)
    color_glow_frac = glow_count / total

    return {
        "inkFrac": ink_count / total,
        "edgeDensity": edge_density,
        "distinctLuma": distinct_luma,
        "blackFrac": black_count / total,
        "meanLuma": mean_luma,
        "colorGlowFrac": color_glow_frac,
    }


def compare(a: Image.Image, b: Image.Image) -> dict[str, Any]:
    """Compare two images of identical size; return diff stats.

    - meanAbsDiff:  mean absolute per-pixel luma difference (0..255 scale).
    - changedFrac:  fraction of pixels whose luma differs by more than
                     INK_LUMA_THRESHOLD's neighbor magnitude (using the same
                     BLACK_LUMA_THRESHOLD-scale "did this pixel move" cut —
                     concretely, abs diff > BLACK_LUMA_THRESHOLD counts as
                     "changed").
    - maxAbsDiff:   the single largest per-pixel luma difference observed.
    """
    if a.size != b.size:
        raise ValueError(f"compare() requires equal-size images, got {a.size} vs {b.size}")

    la = _luma_channel(a)
    lb = _luma_channel(b)
    diff = ImageChops.difference(la, lb)
    hist = diff.histogram()
    total = sum(hist)
    if total == 0:
        return {"meanAbsDiff": 0.0, "changedFrac": 0.0, "maxAbsDiff": 0}

    mean_abs_diff = sum(i * c for i, c in enumerate(hist)) / total
    changed_count = sum(hist[BLACK_LUMA_THRESHOLD + 1:])
    changed_frac = changed_count / total
    max_abs_diff = max(i for i, c in enumerate(hist) if c > 0)

    return {
        "meanAbsDiff": mean_abs_diff,
        "changedFrac": changed_frac,
        "maxAbsDiff": max_abs_diff,
    }


def save_diff(a: Image.Image, b: Image.Image, path: str) -> str:
    """Save a human-readable comparison strip: [a | b | abs-diff] side by side.

    Images are resized to a common height (the smaller of the two) before
    laying out, so mismatched-size inputs still produce a usable image
    instead of raising. The diff panel is computed on the (possibly resized)
    luma channels and rendered back to RGB (grayscale-in-RGB) so it composites
    cleanly next to the two color panels.
    """
    h = min(a.height, b.height)

    def _resize_to_h(img: Image.Image, target_h: int) -> Image.Image:
        if img.height == target_h:
            return img
        w = round(img.width * (target_h / img.height))
        return img.resize((w, target_h))

    a_r = _resize_to_h(a, h)
    b_r = _resize_to_h(b, h)

    la = _luma_channel(a_r)
    lb = _luma_channel(b_r)
    if la.size != lb.size:
        # Different aspect ratios after height-matching — pad the diff panel
        # to the max width rather than raising, so this stays a pure "for
        # humans to look at" convenience function.
        w = max(la.width, lb.width)
        la = la.crop((0, 0, w, h))
        lb = lb.crop((0, 0, w, h))
    diff_l = ImageChops.difference(la, lb)
    diff_rgb = diff_l.convert("RGB")

    total_w = a_r.width + b_r.width + diff_rgb.width
    strip = Image.new("RGB", (total_w, h), (0, 0, 0))
    x = 0
    for panel in (a_r.convert("RGB"), b_r.convert("RGB"), diff_rgb):
        strip.paste(panel, (x, 0))
        x += panel.width

    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    strip.save(p)
    return str(p)
