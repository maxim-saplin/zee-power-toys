#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0", "pillow>=10.0"]
# ///
"""zee_diff.py — the comparison gate: A/B pixel verdicts, not existence proofs.

Why this exists: 26 delivery Blocks in this repo were signed off as
"runtime-confirmed with an attached screenshot", and the app was still
visibly broken on first human use. The gate accepted *existence* (a PNG
exists, dimensions match) but never *comparison* (does this differ from
that; does this region actually show detail). The concrete failure this
was built to catch: Block 0021 tuned the HUD minimap filter for readability
at full-bleed 1280x720; Block 0025 correctly confined the map to a 210x210
Safe-Area square and silently destroyed that readability (the map still
renders at the wide-area zoom). Both Blocks passed their existence-only
gate. See `selftest` below — it reproduces that exact regression as a
checked-in numeric assertion against the two committed shots:
  shots/redo/t2-hud-final-readable.png     (good)
  shots/redo/t2-hud-minimap-confined.png   (regression)

CALIBRATION (Task 2 finding — report honestly, do not tune to agree):
Measured against CALIBRATION_ROI_1280x720 (the 1280x720-era geometry those
two files were captured at):
                    edgeDensity   distinctLuma
  good (readable)      0.144          196
  mush (confined)      0.102           80
distinctLuma reproduces the expected ~196 / ~81 almost exactly. edgeDensity
shows the same *direction* of separation (good > mush) but a materially
smaller ratio (1.4x measured vs ~2.5x guessed) and different absolute values
(0.144/0.102 measured vs ~0.212/~0.083 guessed) — most likely a difference in
how "edge density" was computed upstream (FIND_EDGES threshold/kernel choice
is not unique). DEFAULT_MIN_EDGE_DENSITY below is set from the *measured*
numbers (0.12, roughly midway between 0.102 and 0.144), not the guessed ones,
per instruction: the measurement is the deliverable, not agreement with the
guess.

Whole-frame contrast (why ROI cropping is mandatory, not optional): computed
over the full 1280x720 frame, the confined shot's inkFrac is ~33x smaller
than the readable shot's (0.184 vs 0.0055) and edgeDensity ~25x smaller. That
is true and useless: the map merely moved into a small square elsewhere in
the frame, so almost the entire frame is emissive-black background in BOTH
shots' cases, and any whole-frame threshold set to catch the regression would
also fire on "user resized the minimap to compact preset" (a legitimate
change) — it is either always-pass or always-fail w.r.t. the actual question
("is the map, where it now lives, still readable").

`--roi minimap` NEVER hardcodes minimap geometry: it always reads the rect
from `ext.zee.readViewModel` (surface=dhu) — see `_resolve_roi_from_geo()`.
Reimplementing computeMinimapViewport() here would let the two copies drift
apart, which is exactly the class of bug this tool exists to catch (see
docs/issues/0009-minimap-under-layer.md and Block 0027 history). The one
exception is `selftest`, which records the *fixed, historical* ROI for two
*specific, archived* 1280x720 files that predate the live app's current
1024x576 display config — that is calibration data for two named files, not
a live geometry computation.

Subcommands (JSON to stdout always; non-zero exit on failure/verdict-mismatch):
  selftest                                     Task 2 regression, no device needed
  metrics  --surface hud --layer native --roi {full,minimap}
  readable --surface hud --roi minimap [--min-edge-density] [--min-distinct]
  differs  A.png B.png --roi {full,minimap} [--min-changed-frac]
  same     A.png B.png --roi {full,minimap} [--max-changed-frac]
  ab       --set-a "K=V[,K=V...]" --set-b "K=V[,K=V...]" --surface hud
           --layer native --roi minimap --expect {differs,same} [--freeze]

Cadence (.agents/skills/drive-zee-app/SKILL.md: >7 mutating RPCs/s wedges the
WebSocket): every mutating RPC (setConfig, inject) in this file is separated
by at least MIN_MUTATION_GAP_S, and every capture that follows a mutation
waits SETTLE_S first.

Stability pre-check (`ab` only, do not skip): before trusting any A/B
verdict, two captures STABILITY_GAP_S apart with NO config change in between
are compared. If they already differ by more than
--stability-max-changed-frac, the surface is animating (a blinking blinker,
a live map camera) and any verdict right now is a coin flip — this reports
`"unstable": true` and fails, unless `--freeze` was passed, in which case the
blinker is switched off first (`inject kind=blinker value=off`) and the
pre-check is retried implicitly by simply proceeding — if it's STILL
unstable after that, something else is animating and that is reported too,
not swallowed.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(__file__))
import feedback_loop as fl          # FeedbackLoop, shot_native, T1NativeStub, T2NativeChannel
import zee_drive as _z              # DEFAULT_SERIAL, resolve_ws_uri
import zee_pixels as zp             # load, crop_roi, metrics, compare, save_diff

# ---------------------------------------------------------------------------
# Cadence / settle constants — see module docstring.
# ---------------------------------------------------------------------------
MIN_MUTATION_GAP_S = 0.25
SETTLE_S = 1.2
STABILITY_GAP_S = 0.3

# ---------------------------------------------------------------------------
# Default thresholds — see CALIBRATION note in the module docstring for how
# these were derived (from measured numbers, not the task's guessed ones).
# ---------------------------------------------------------------------------
DEFAULT_MIN_EDGE_DENSITY = 0.12
DEFAULT_MIN_DISTINCT_LUMA = 120
DEFAULT_MIN_CHANGED_FRAC_DIFFERS = 0.05
DEFAULT_MAX_CHANGED_FRAC_SAME = 0.01
DEFAULT_STABILITY_MAX_CHANGED_FRAC = 0.02
# Measured, not guessed: the known-good calibration shot scores colorGlowFrac
# ~0.005 and the known-mush one ~0.0; a HUD minimap filter later rejected for
# a visibly-glowing navy background (accepted on every other metric) measured
# 0.016-0.023 in the same ROI. 0.01 sits cleanly between "real reference
# renders" and "a defect a human eye caught" — see zee_pixels.metrics'
# colorGlowFrac docstring for the full account.
DEFAULT_MAX_COLOR_GLOW_FRAC = 0.01

# ---------------------------------------------------------------------------
# Fixed historical calibration data (Task 2) — see module docstring for why
# this is NOT a live-geometry reimplementation.
# ---------------------------------------------------------------------------
CALIBRATION_ROI_1280x720 = (278, 263, 210, 210)
CALIBRATION_SHOTS = {
    "good": "shots/redo/t2-hud-final-readable.png",
    "mush": "shots/redo/t2-hud-minimap-confined.png",
}


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def _round_metrics(m: dict[str, Any]) -> dict[str, Any]:
    return {k: (round(v, 4) if isinstance(v, float) else v) for k, v in m.items()}


def _is_readable(
    m: dict[str, Any],
    *,
    min_edge_density: float,
    min_distinct: float,
    max_color_glow_frac: float | None = None,
) -> bool:
    """A region is 'readable' only when it clears BOTH detail signals:
    edgeDensity (geometric detail per area) AND distinctLuma (tonal variety).
    Requiring both avoids false positives from e.g. bright uniform noise
    (high edge count, few distinct tones) or a smooth gradient (many tones,
    no real edges) — either alone is gameable, together they are not.

    [max_color_glow_frac] is a THIRD, independent gate (default None = not
    enforced, for callers/tests written before this existed): "detailed" and
    "not emissive-glowing" are different questions — a filter can have great
    edgeDensity/distinctLuma while still leaving a visibly-glowing background
    wash (see zee_pixels.metrics' colorGlowFrac docstring for the concrete
    HUD-minimap-filter case this was built to catch: a rejected candidate
    that read as "mostly dark" by blackFrac alone).
    """
    detail_ok = m["edgeDensity"] >= min_edge_density and m["distinctLuma"] >= min_distinct
    if max_color_glow_frac is None:
        return detail_ok
    return detail_ok and m["colorGlowFrac"] <= max_color_glow_frac


def _parse_kv_string(s: str) -> dict[str, str]:
    """Parse 'K=V' or 'K=V,K2=V2' into a dict."""
    out: dict[str, str] = {}
    for part in s.split(","):
        part = part.strip()
        if not part:
            continue
        if "=" not in part:
            raise ValueError(f"bad key=value entry {part!r} in {s!r}")
        k, v = part.split("=", 1)
        out[k.strip()] = v.strip()
    return out


def _resolve_roi_from_geo(roi_name: str, geo: dict[str, Any]) -> tuple[int, int, int, int]:
    """Resolve --roi {full,minimap} from a read-view-model geo dict
    ({'hud': {...}, 'viewport': {...}}). Never hardcodes minimap geometry —
    'minimap' always comes from the app's own `viewport` field.
    """
    if roi_name == "full":
        hud = geo.get("hud") or {}
        if not hud:
            raise RuntimeError(
                "read-view-model returned no 'hud' field — is the dhu surface up?"
            )
        return (0, 0, int(hud["w"]), int(hud["h"]))
    if roi_name == "minimap":
        vp = geo.get("viewport")
        if not vp:
            raise RuntimeError(
                "read-view-model returned no 'viewport' field — the app's own "
                "minimap ROI (Block 0027) is unavailable. Refusing to guess "
                "the geometry in Python."
            )
        return (
            int(round(vp["x"])), int(round(vp["y"])),
            int(round(vp["w"])), int(round(vp["h"])),
        )
    raise ValueError(f"unknown --roi {roi_name!r}")


def _native_channel(tier: str, serial: str) -> fl.NativeChannel:
    if tier in ("t2", "t3"):
        return fl.T2NativeChannel(serial=serial)
    return fl.T1NativeStub()


async def _fetch_geo(loop: fl.FeedbackLoop) -> dict[str, Any]:
    """Read {'hud':..., 'viewport':...} via ext.zee.readViewModel(dhu).

    Block 0027 populates these fields on the dhu surface specifically — see
    .agents/skills/drive-zee-app/SKILL.md's readViewModel row.
    """
    vm = await loop.read_view_model("dhu")
    return {"hud": vm.get("hud"), "viewport": vm.get("viewport")}


# ---------------------------------------------------------------------------
# selftest — Task 2 as a checked-in regression. No device/VM needed.
# ---------------------------------------------------------------------------

def cmd_selftest(args: argparse.Namespace) -> tuple[int, dict[str, Any]]:
    roi = CALIBRATION_ROI_1280x720
    raw: dict[str, dict[str, Any]] = {}
    for label, path in CALIBRATION_SHOTS.items():
        img = zp.load(path)
        whole_m = zp.metrics(img)
        roi_m = zp.metrics(zp.crop_roi(img, roi))
        raw[label] = {"path": path, "wholeFrame": whole_m, "roi": roi_m}

    good_ok = _is_readable(
        raw["good"]["roi"],
        min_edge_density=args.min_edge_density,
        min_distinct=args.min_distinct,
        max_color_glow_frac=args.max_color_glow_frac,
    )
    mush_ok = _is_readable(
        raw["mush"]["roi"],
        min_edge_density=args.min_edge_density,
        min_distinct=args.min_distinct,
        max_color_glow_frac=args.max_color_glow_frac,
    )
    passed = good_ok and not mush_ok

    result = {
        "roi": list(roi),
        "roiNote": (
            "fixed 1280x720-era geometry these two archived shots were "
            "captured at (Block 0021->0025 regression); NOT the live app's "
            "current viewport (1024x576 on the T2 emulator as of this "
            "writing) — see module docstring."
        ),
        "shots": {
            k: {
                "path": v["path"],
                "wholeFrame": _round_metrics(v["wholeFrame"]),
                "roi": _round_metrics(v["roi"]),
            }
            for k, v in raw.items()
        },
        "minEdgeDensity": args.min_edge_density,
        "minDistinct": args.min_distinct,
        "maxColorGlowFrac": args.max_color_glow_frac,
        "goodReadable": good_ok,
        "mushReadable": mush_ok,
        "pass": passed,
    }
    return (0 if passed else 1), result


# ---------------------------------------------------------------------------
# metrics
# ---------------------------------------------------------------------------

async def _run_metrics(args: argparse.Namespace, ws_uri: str) -> dict[str, Any]:
    native = _native_channel(args.tier, args.serial)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    async def _fn(loop: fl.FeedbackLoop) -> dict[str, Any]:
        geo = await _fetch_geo(loop)
        roi = _resolve_roi_from_geo(args.roi, geo)
        captures: dict[str, Any] = {}
        metrics_by_layer: dict[str, Any] = {}
        if args.layer in ("native", "both"):
            path = str(out_dir / f"metrics-{args.surface}-native.png")
            cap = fl.shot_native(args.surface, path, serial=args.serial)
            if "error" in cap:
                raise RuntimeError(f"native capture failed: {cap}")
            captures["native"] = cap
            img = zp.crop_roi(zp.load(path), roi)
            metrics_by_layer["native"] = _round_metrics(zp.metrics(img))
        if args.layer in ("flutter", "both"):
            path = str(out_dir / f"metrics-{args.surface}-flutter.png")
            cap = await loop.shot(args.surface, out_path=path)
            captures["flutter"] = cap
            img = zp.crop_roi(zp.load(path), roi)
            metrics_by_layer["flutter"] = _round_metrics(zp.metrics(img))
        return {
            "surface": args.surface,
            "layer": args.layer,
            "roi": args.roi,
            "roiRect": list(roi),
            "captures": captures,
            "metrics": metrics_by_layer,
        }

    return await fl._open_feedback_loop(ws_uri, native, _fn)


# ---------------------------------------------------------------------------
# readable
# ---------------------------------------------------------------------------

async def _run_readable(args: argparse.Namespace, ws_uri: str) -> dict[str, Any]:
    native = _native_channel(args.tier, args.serial)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    async def _fn(loop: fl.FeedbackLoop) -> dict[str, Any]:
        geo = await _fetch_geo(loop)
        roi = _resolve_roi_from_geo(args.roi, geo)
        path = str(out_dir / f"readable-{args.surface}.png")
        cap = fl.shot_native(args.surface, path, serial=args.serial)
        if "error" in cap:
            raise RuntimeError(f"native capture failed: {cap}")
        img = zp.crop_roi(zp.load(path), roi)
        m = zp.metrics(img)
        ok = _is_readable(
            m,
            min_edge_density=args.min_edge_density,
            min_distinct=args.min_distinct,
            max_color_glow_frac=args.max_color_glow_frac,
        )
        return {
            "surface": args.surface,
            "roi": args.roi,
            "roiRect": list(roi),
            "shot": path,
            "metrics": _round_metrics(m),
            "minEdgeDensity": args.min_edge_density,
            "minDistinct": args.min_distinct,
            "maxColorGlowFrac": args.max_color_glow_frac,
            "pass": ok,
        }

    return await fl._open_feedback_loop(ws_uri, native, _fn)


# ---------------------------------------------------------------------------
# differs / same — operate on two already-captured PNG files.
# ---------------------------------------------------------------------------

def _load_and_crop_pair(
    a_path: str, b_path: str, roi_name: str, *, ws_uri: str | None, serial: str, tier: str,
) -> tuple[Any, Any, tuple[int, int, int, int]]:
    a_img = zp.load(a_path)
    b_img = zp.load(b_path)

    if roi_name == "full":
        # No live app needed: 'full' is just each image's own bounds. If A
        # and B are different sizes, compare() will raise — that is a real
        # problem to surface, not something to silently paper over.
        roi_a = (0, 0, a_img.width, a_img.height)
        roi_b = (0, 0, b_img.width, b_img.height)
        return zp.crop_roi(a_img, roi_a), zp.crop_roi(b_img, roi_b), roi_a

    if roi_name == "minimap":
        if ws_uri is None:
            raise RuntimeError("--roi minimap requires a live VM connection to read viewport")
        native = _native_channel(tier, serial)

        async def _fn(loop: fl.FeedbackLoop) -> dict[str, Any]:
            return await _fetch_geo(loop)

        geo = asyncio.run(fl._open_feedback_loop(ws_uri, native, _fn))
        roi = _resolve_roi_from_geo("minimap", geo)
        x, y, w, h = roi
        for label, img in (("A", a_img), ("B", b_img)):
            if x + w > img.width or y + h > img.height:
                raise RuntimeError(
                    f"live viewport {roi} does not fit inside image {label} "
                    f"({img.size}) — {label} was likely captured at a "
                    "different display resolution than the live app is "
                    "currently reporting; refusing to crop with mismatched "
                    "geometry (see selftest's fixed-ROI note for the pattern "
                    "this is guarding against)"
                )
        return zp.crop_roi(a_img, roi), zp.crop_roi(b_img, roi), roi

    raise ValueError(f"unknown --roi {roi_name!r}")


def cmd_differs(args: argparse.Namespace, ws_uri: str | None) -> tuple[int, dict[str, Any]]:
    a_img, b_img, roi = _load_and_crop_pair(
        args.a, args.b, args.roi, ws_uri=ws_uri, serial=args.serial, tier=args.tier,
    )
    cmp = zp.compare(a_img, b_img)
    ok = cmp["changedFrac"] >= args.min_changed_frac
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    diff_path = zp.save_diff(a_img, b_img, str(out_dir / "differs-diff.png"))
    result = {
        "a": args.a, "b": args.b, "roi": args.roi, "roiRect": list(roi),
        "compare": _round_metrics(cmp), "minChangedFrac": args.min_changed_frac,
        "diffImage": diff_path, "pass": ok,
    }
    return (0 if ok else 1), result


def cmd_same(args: argparse.Namespace, ws_uri: str | None) -> tuple[int, dict[str, Any]]:
    a_img, b_img, roi = _load_and_crop_pair(
        args.a, args.b, args.roi, ws_uri=ws_uri, serial=args.serial, tier=args.tier,
    )
    cmp = zp.compare(a_img, b_img)
    ok = cmp["changedFrac"] <= args.max_changed_frac
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    diff_path = zp.save_diff(a_img, b_img, str(out_dir / "same-diff.png"))
    result = {
        "a": args.a, "b": args.b, "roi": args.roi, "roiRect": list(roi),
        "compare": _round_metrics(cmp), "maxChangedFrac": args.max_changed_frac,
        "diffImage": diff_path, "pass": ok,
    }
    return (0 if ok else 1), result


# ---------------------------------------------------------------------------
# ab — set_config(A) -> settle -> capture -> set_config(B) -> settle ->
#      capture -> compare. Stability pre-check gates the whole thing.
# ---------------------------------------------------------------------------

async def _run_ab(args: argparse.Namespace, ws_uri: str) -> dict[str, Any]:
    native = _native_channel(args.tier, args.serial)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    set_a = _parse_kv_string(args.set_a)
    set_b = _parse_kv_string(args.set_b)

    async def _fn(loop: fl.FeedbackLoop) -> dict[str, Any]:
        geo = await _fetch_geo(loop)
        roi = _resolve_roi_from_geo(args.roi, geo)

        # --freeze: neutralize the one known animation source (the blinker)
        # before judging stability. This is a mutating RPC — respect cadence.
        if args.freeze:
            await loop.inject("dhu", kind="blinker", value="off")
            await asyncio.sleep(MIN_MUTATION_GAP_S)

        # Stability pre-check — two captures, NO config mutation in between.
        s1_path = str(out_dir / "stability-1.png")
        s2_path = str(out_dir / "stability-2.png")
        cap1 = fl.shot_native(args.surface, s1_path, serial=args.serial)
        if "error" in cap1:
            raise RuntimeError(f"native capture failed: {cap1}")
        await asyncio.sleep(STABILITY_GAP_S)
        cap2 = fl.shot_native(args.surface, s2_path, serial=args.serial)
        if "error" in cap2:
            raise RuntimeError(f"native capture failed: {cap2}")

        s1_img = zp.crop_roi(zp.load(s1_path), roi)
        s2_img = zp.crop_roi(zp.load(s2_path), roi)
        stability_cmp = zp.compare(s1_img, s2_img)
        unstable = stability_cmp["changedFrac"] > args.stability_max_changed_frac

        result: dict[str, Any] = {
            "surface": args.surface, "layer": args.layer, "roi": args.roi,
            "roiRect": list(roi), "freeze": args.freeze,
            "stability": {
                **_round_metrics(stability_cmp),
                "gapSeconds": STABILITY_GAP_S,
                "maxChangedFrac": args.stability_max_changed_frac,
            },
            "unstable": unstable,
        }

        if unstable:
            result["pass"] = False
            result["reason"] = (
                "stability pre-check failed: two captures "
                f"{STABILITY_GAP_S}s apart with NO config change differ by "
                f"changedFrac={stability_cmp['changedFrac']:.4f} > "
                f"{args.stability_max_changed_frac} — the surface is "
                "animating (e.g. a blinking indicator or live map camera); "
                "any A/B verdict taken right now would be a coin flip. Pass "
                "--freeze to neutralize the blinker, or investigate what "
                "else is animating."
            )
            return result

        # The real A/B.
        await loop.set_config("dhu", **set_a)
        await asyncio.sleep(SETTLE_S)
        a_path = str(out_dir / "a.png")
        cap_a = fl.shot_native(args.surface, a_path, serial=args.serial)
        if "error" in cap_a:
            raise RuntimeError(f"native capture failed: {cap_a}")

        await loop.set_config("dhu", **set_b)
        await asyncio.sleep(SETTLE_S)
        b_path = str(out_dir / "b.png")
        cap_b = fl.shot_native(args.surface, b_path, serial=args.serial)
        if "error" in cap_b:
            raise RuntimeError(f"native capture failed: {cap_b}")

        a_img = zp.crop_roi(zp.load(a_path), roi)
        b_img = zp.crop_roi(zp.load(b_path), roi)
        cmp = zp.compare(a_img, b_img)
        diff_path = zp.save_diff(a_img, b_img, str(out_dir / "ab-diff.png"))

        differs_ok = cmp["changedFrac"] >= args.min_changed_frac
        same_ok = cmp["changedFrac"] <= args.max_changed_frac
        verdict_pass = differs_ok if args.expect == "differs" else same_ok

        result.update({
            "setA": set_a, "setB": set_b,
            "aShot": a_path, "bShot": b_path, "diffImage": diff_path,
            "compare": _round_metrics(cmp),
            "expect": args.expect,
            "minChangedFrac": args.min_changed_frac,
            "maxChangedFrac": args.max_changed_frac,
            "pass": verdict_pass,
        })
        return result

    return await fl._open_feedback_loop(ws_uri, native, _fn)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Pixel-level A/B comparison gate for zee-power-toys HUD — "
        "the comparison primitive that existence-only screenshot sign-off was missing."
    )
    p.add_argument("--vm-uri", default=None, help="VM-service URI override (else $ZEE_VM_URI / session file)")
    p.add_argument("--serial", default=_z.DEFAULT_SERIAL, help="adb serial (default: %(default)s)")
    p.add_argument("--tier", choices=["t1", "t2", "t3"], default="t2", help="target tier (default: %(default)s)")
    p.add_argument("--out-dir", default="/tmp/zee_diff", help="dir for captured PNGs + diff strips (default: %(default)s)")
    sub = p.add_subparsers(dest="cmd", required=True)

    st = sub.add_parser("selftest", help="Task 2 regression against the two committed Block 0021->0025 shots (no device needed)")
    st.add_argument("--min-edge-density", type=float, default=DEFAULT_MIN_EDGE_DENSITY)
    st.add_argument("--min-distinct", type=float, default=DEFAULT_MIN_DISTINCT_LUMA)
    st.add_argument("--max-color-glow-frac", type=float, default=DEFAULT_MAX_COLOR_GLOW_FRAC)

    me = sub.add_parser("metrics", help="capture + compute metrics for a surface/roi")
    me.add_argument("--surface", required=True, choices=["dhu", "hud"])
    me.add_argument("--layer", choices=["flutter", "native", "both"], default="native")
    me.add_argument("--roi", required=True, choices=["full", "minimap"])

    rd = sub.add_parser("readable", help="capture + assert a region clears the readability thresholds")
    rd.add_argument("--surface", default="hud", choices=["dhu", "hud"])
    rd.add_argument("--roi", default="minimap", choices=["full", "minimap"])
    rd.add_argument("--min-edge-density", type=float, default=DEFAULT_MIN_EDGE_DENSITY)
    rd.add_argument("--min-distinct", type=float, default=DEFAULT_MIN_DISTINCT_LUMA)
    rd.add_argument(
        "--max-color-glow-frac", type=float, default=DEFAULT_MAX_COLOR_GLOW_FRAC,
        help="reject a region that is 'detailed' by edge/distinct-luma but still "
             "has a real per-channel emissive glow where it should be off (e.g. a "
             "dim colored background wash) — see zee_pixels.metrics colorGlowFrac",
    )

    df = sub.add_parser("differs", help="assert two saved PNGs differ (in --roi) by at least --min-changed-frac")
    df.add_argument("a")
    df.add_argument("b")
    df.add_argument("--roi", required=True, choices=["full", "minimap"])
    df.add_argument("--min-changed-frac", type=float, default=DEFAULT_MIN_CHANGED_FRAC_DIFFERS)

    sm = sub.add_parser("same", help="assert two saved PNGs are the same (in --roi) within --max-changed-frac")
    sm.add_argument("a")
    sm.add_argument("b")
    sm.add_argument("--roi", required=True, choices=["full", "minimap"])
    sm.add_argument("--max-changed-frac", type=float, default=DEFAULT_MAX_CHANGED_FRAC_SAME)

    ab = sub.add_parser("ab", help="set_config(A) -> settle -> capture -> set_config(B) -> settle -> capture -> compare")
    ab.add_argument("--set-a", required=True, help="'KEY=VAL[,KEY=VAL...]' — ext.zee.setConfig params for state A")
    ab.add_argument("--set-b", required=True, help="'KEY=VAL[,KEY=VAL...]' — ext.zee.setConfig params for state B")
    ab.add_argument("--surface", default="hud", choices=["dhu", "hud"])
    ab.add_argument("--layer", choices=["native"], default="native", help="only 'native' can see the map composite (see docs/issues/0009)")
    ab.add_argument("--roi", default="minimap", choices=["full", "minimap"])
    ab.add_argument("--expect", required=True, choices=["differs", "same"])
    ab.add_argument("--freeze", action="store_true", help="inject kind=blinker value=off before the stability pre-check")
    ab.add_argument("--min-changed-frac", type=float, default=DEFAULT_MIN_CHANGED_FRAC_DIFFERS, help="used when --expect differs")
    ab.add_argument("--max-changed-frac", type=float, default=DEFAULT_MAX_CHANGED_FRAC_SAME, help="used when --expect same")
    ab.add_argument("--stability-max-changed-frac", type=float, default=DEFAULT_STABILITY_MAX_CHANGED_FRAC)

    return p


def main(argv: list[str] | None = None) -> int:
    p = build_parser()
    args = p.parse_args(argv)

    if args.cmd == "selftest":
        rc, result = cmd_selftest(args)
        print(json.dumps(result, indent=2))
        return rc

    needs_vm = args.cmd in ("metrics", "readable", "ab") or (
        args.cmd in ("differs", "same") and args.roi == "minimap"
    )
    ws_uri: str | None = None
    if needs_vm:
        try:
            ws_uri = _z.resolve_ws_uri(serial=args.serial, override=args.vm_uri, tier=args.tier)
        except Exception as e:
            print(json.dumps({"error": f"VM discovery failed: {e}"}, indent=2), file=sys.stderr)
            return 3

    try:
        if args.cmd == "metrics":
            result = asyncio.run(_run_metrics(args, ws_uri))
            rc = 0
        elif args.cmd == "readable":
            result = asyncio.run(_run_readable(args, ws_uri))
            rc = 0 if result.get("pass") else 1
        elif args.cmd == "differs":
            rc, result = cmd_differs(args, ws_uri)
        elif args.cmd == "same":
            rc, result = cmd_same(args, ws_uri)
        elif args.cmd == "ab":
            result = asyncio.run(_run_ab(args, ws_uri))
            rc = 0 if result.get("pass") else 1
        else:  # pragma: no cover
            raise ValueError(f"unknown command {args.cmd!r}")
    except Exception as e:
        print(json.dumps({"error": str(e)}, indent=2), file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2))
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
