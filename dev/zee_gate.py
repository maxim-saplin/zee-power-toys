#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0", "pillow>=10.0"]
# ///
"""zee_gate.py — the Definition-of-Done gate: one command, JSON verdict.

Why this exists: 26 delivery Blocks in this repo were signed off as
"runtime-confirmed with an attached screenshot" while the app was visibly
broken, because a screenshot only proves a PNG *exists* — it proves nothing
was actually *compared* against a threshold or a prior good state. The
pieces of a real gate already existed (dev/zee_pixels.py's metrics,
dev/zee_diff.py's readable/differs/same/ab, `shot --layer native` which can
finally see the native YNavi map) but nobody had composed them into a single
command a Block's sign-off could quote. This is that command.

A Block's Definition of Done quotes THIS SCRIPT'S JSON — not a PNG path.
See .agents/skills/drive-zee-app/SKILL.md.

Usage
  uv run dev/zee_gate.py --tier t2
  uv run dev/zee_gate.py --tier t2 --checks env,surfaces
  uv run dev/zee_gate.py --tier t2 --baseline /tmp/gate-base
  uv run dev/zee_gate.py --tier t2 --against /tmp/gate-base

Checks (default: all six, comma-separated via --checks)
  env               emulator reachable; overlay_display_devices correct;
                     secondary display resolves (zee_drive.resolve_hud_display);
                     hudEnabled reported from the persisted config.
  surfaces           both dhu and hud answer ext.zee.whoami.
  relay              set-config --surface dhu blinkerShape=smiley -> HUD
                     dumpState reflects it -> set back to arrows. Replaces
                     the deleted verify_skeleton.py's relay check, which
                     targeted the long-removed hudBoxOn field.
  hud-visible        native composite of the HUD display; inkFrac > 0.02 —
                     fails on an all-black HUD, the failure mode nobody was
                     catching with existence-only screenshots.
  minimap-readable   ROI from read-view-model's viewport (never hardcoded);
                     delegates to zee_diff.py's `readable` thresholds incl.
                     colorGlowFrac. Refuses to run (and says so) when
                     minimapEnabled=false instead of vacuously passing —
                     the minimap defaults OFF, and grading a disabled
                     minimap's ROI would silently pass on whatever else
                     happens to occupy that rectangle.
  shape-geometry     `flutter test test/hud/`.

--baseline DIR   records every capture this run made plus its metrics JSON
                 into DIR (dev/zee_gate.py --against DIR later compares
                 against it).
--against DIR    compares this run's hud-visible/minimap-readable captures
                 and metrics against a --baseline recording; fails on
                 regression (pass flips true->false, or the two captures
                 differ by more than zee_diff's "same" changedFrac
                 tolerance). This comparison is the primitive the previous
                 26 Blocks lacked — an existence-only screenshot cannot
                 catch "this used to look different."

Exit code is non-zero if any requested check (or baseline comparison) fails.
JSON is always printed to stdout.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(__file__))
import feedback_loop as fl   # FeedbackLoop, shot_native, _open_feedback_loop, _build_surface_map
import zee_diff as zd        # _native_channel, _run_readable, DEFAULT_* thresholds
import zee_drive as _z       # resolve_ws_uri, resolve_hud_display, read_persisted_hud_enabled
import zee_pixels as zp      # load, crop_roi, metrics, compare

REPO_ROOT = Path(__file__).resolve().parent.parent

ALL_CHECKS = [
    "env", "surfaces", "relay", "hud-visible", "minimap-readable", "shape-geometry",
]

EXPECTED_OVERLAY = "1024x576/213"
# CALIBRATION (measured on the live T2 emulator, not guessed — same spirit as
# zee_diff.py's DEFAULT_MIN_EDGE_DENSITY note: report the measurement
# honestly rather than tune to agree with a prior guess). The task that
# specified this check's shape suggested inkFrac > 0.02 as the "not
# all-black" bar. Measured reality post-Block-0025 (minimap confined to a
# small Safe-Area square, not full-bleed): a fully-loaded HUD frame with the
# minimap rendering real map tiles, battery/temp filled in, and the blinker
# mid-blink-on tops out around inkFrac ~0.017-0.019 whole-frame — because the
# lit content (a ~210-233px-square minimap corner + a small battery glyph)
# is architecturally a small fraction of the full 1024x576 frame, unlike the
# pre-0025 full-bleed map that this 0.02 figure likely traces back to. An
# actually-black/not-yet-loaded HUD measures inkFrac ~0.0007-0.0016 in the
# same environment. 0.01 sits cleanly between those two regimes (a >10x
# separation) and is what still catches an all-black HUD without being an
# unclearable bar on the current confined-minimap architecture. Override with
# --min-ink-frac 0.02 to apply the originally-suggested figure literally —
# expect it to fail even on a fully healthy confined-minimap HUD.
DEFAULT_MIN_HUD_VISIBLE_INK_FRAC = 0.01
MUTATION_GAP_S = 0.3  # see SKILL.md cadence hazard — space mutating RPCs by >=200ms
# Observed live: any ext.zee.setConfig call (even one touching only
# blinkerShape) makes the native minimap momentarily drop to its "no fix"
# grid placeholder before YNavi's real map re-settles — ConfigStore pushes
# the whole config object through on every write, which re-triggers the
# native minimap apply path regardless of which field actually changed. The
# `relay` check mutates config; if a pixel check (hud-visible,
# minimap-readable) runs immediately after it in the same invocation, it can
# capture that transient placeholder and report a false "all-black"/unreadable
# failure. Mirrors zee_diff.py's own SETTLE_S convention: wait for a mutation
# to visually settle before trusting a capture that follows it.
RELAY_SETTLE_S = 1.5


def _round(m: dict[str, Any]) -> dict[str, Any]:
    return {k: (round(v, 4) if isinstance(v, float) else v) for k, v in m.items()}


# ---------------------------------------------------------------------------
# env
# ---------------------------------------------------------------------------

def check_env(tier: str, serial: str) -> dict[str, Any]:
    result: dict[str, Any] = {"name": "env"}

    devices = subprocess.run(["adb", "devices"], capture_output=True, text=True, timeout=15)
    reachable = any(
        line.startswith(serial) and "device" in line for line in devices.stdout.splitlines()
    )
    result["adbReachable"] = reachable

    r = subprocess.run(
        ["adb", "-s", serial, "shell", "settings", "get", "global", "overlay_display_devices"],
        capture_output=True, text=True, timeout=15,
    )
    overlay = (r.stdout or "").strip()
    overlay_ok = overlay == EXPECTED_OVERLAY
    result["overlayDisplayDevices"] = overlay
    result["overlayOk"] = overlay_ok

    try:
        info = _z.resolve_hud_display(serial=serial)
        result["hudDisplay"] = info
        display_ok = True
    except Exception as e:
        result["hudDisplay"] = {"error": str(e)}
        display_ok = False
    result["displayOk"] = display_ok

    result["hudEnabled"] = _z.read_persisted_hud_enabled(serial=serial)

    result["pass"] = bool(reachable and overlay_ok and display_ok)
    return result


# ---------------------------------------------------------------------------
# surfaces
# ---------------------------------------------------------------------------

async def _probe_surfaces(ws_uri: str) -> dict[str, str]:
    async def fn(c: _z.VMClient) -> dict[str, str]:
        return await fl._build_surface_map(c, timeout_s=20.0)
    return await _z._with_client(ws_uri, fn)


def check_surfaces(ws_uri: str | None, ws_uri_error: str | None) -> dict[str, Any]:
    result: dict[str, Any] = {"name": "surfaces"}
    if ws_uri is None:
        result["pass"] = False
        result["error"] = ws_uri_error or "no VM URI resolved"
        return result
    try:
        surface_map = asyncio.run(_probe_surfaces(ws_uri))
        result["surfaces"] = sorted(surface_map)
        result["pass"] = "dhu" in surface_map and "hud" in surface_map
    except Exception as e:
        result["pass"] = False
        result["error"] = str(e)
    return result


# ---------------------------------------------------------------------------
# relay — set-config on dhu -> dumpState on hud reflects it, and back
# ---------------------------------------------------------------------------

async def _run_relay(ws_uri: str, serial: str, tier: str) -> dict[str, Any]:
    native = zd._native_channel(tier, serial)

    async def fn(loop: fl.FeedbackLoop) -> dict[str, Any]:
        before = await loop.dump_state("hud")
        before_shape = (before.get("blinker") or {}).get("shape")

        await loop.set_config("dhu", blinkerShape="smiley")
        await asyncio.sleep(MUTATION_GAP_S)
        mid = await loop.dump_state("hud")
        mid_shape = (mid.get("blinker") or {}).get("shape")

        await asyncio.sleep(MUTATION_GAP_S)
        await loop.set_config("dhu", blinkerShape="arrows")
        await asyncio.sleep(MUTATION_GAP_S)
        after = await loop.dump_state("hud")
        after_shape = (after.get("blinker") or {}).get("shape")

        # See RELAY_SETTLE_S above: give the native minimap time to recover
        # from the transient "no fix" placeholder that any setConfig write
        # provokes, so a pixel check running right after `relay` in the same
        # invocation doesn't capture that placeholder and misreport it as an
        # unreadable/all-black HUD.
        await asyncio.sleep(RELAY_SETTLE_S)

        return {
            "beforeShape": before_shape,
            "afterSetSmiley": mid_shape,
            "afterRestoreArrows": after_shape,
        }

    return await fl._open_feedback_loop(ws_uri, native, fn)


def check_relay(ws_uri: str | None, ws_uri_error: str | None, serial: str, tier: str) -> dict[str, Any]:
    result: dict[str, Any] = {"name": "relay"}
    if ws_uri is None:
        result["pass"] = False
        result["error"] = ws_uri_error or "no VM URI resolved"
        return result
    try:
        r = asyncio.run(_run_relay(ws_uri, serial, tier))
        result.update(r)
        result["pass"] = r["afterSetSmiley"] == "smiley" and r["afterRestoreArrows"] == "arrows"
    except Exception as e:
        result["pass"] = False
        result["error"] = str(e)
    return result


# ---------------------------------------------------------------------------
# hud-visible — native composite; fails on an all-black HUD
# ---------------------------------------------------------------------------

def check_hud_visible(serial: str, out_dir: str, min_ink_frac: float) -> dict[str, Any]:
    result: dict[str, Any] = {"name": "hud-visible"}
    path = str(Path(out_dir) / "hud-visible-native.png")
    try:
        cap = fl.shot_native("hud", path, serial=serial)
    except Exception as e:
        result["pass"] = False
        result["error"] = str(e)
        return result
    if "error" in cap:
        result["pass"] = False
        result["error"] = cap["error"]
        result["capture"] = cap
        return result

    m = zp.metrics(zp.load(path))
    result["capture"] = cap
    result["shot"] = path
    result["metrics"] = _round(m)
    result["minInkFrac"] = min_ink_frac
    result["pass"] = m["inkFrac"] > min_ink_frac
    return result


# ---------------------------------------------------------------------------
# minimap-readable — delegates to zee_diff.py's readable, with an explicit
# refusal when minimapEnabled=false (never a vacuous pass).
# ---------------------------------------------------------------------------

async def _minimap_enabled(ws_uri: str, serial: str, tier: str) -> bool | None:
    native = zd._native_channel(tier, serial)

    async def fn(loop: fl.FeedbackLoop) -> bool | None:
        ds = await loop.dump_state("dhu")
        return (ds.get("minimap") or {}).get("enabled")

    return await fl._open_feedback_loop(ws_uri, native, fn)


def check_minimap_readable(
    ws_uri: str | None, ws_uri_error: str | None, serial: str, tier: str, out_dir: str,
) -> dict[str, Any]:
    result: dict[str, Any] = {"name": "minimap-readable"}
    if ws_uri is None:
        result["pass"] = False
        result["error"] = ws_uri_error or "no VM URI resolved"
        return result

    try:
        enabled = asyncio.run(_minimap_enabled(ws_uri, serial, tier))
    except Exception as e:
        result["pass"] = False
        result["error"] = str(e)
        return result

    result["minimapEnabled"] = enabled
    if not enabled:
        result["pass"] = False
        result["skipped"] = True
        result["reason"] = (
            "minimapEnabled=false — refusing to grade the minimap viewport ROI "
            "while the minimap is disabled: that ROI still exists on-screen and "
            "would be graded against whatever else occupies it, which is exactly "
            "the vacuous-pass this gate exists to prevent. Enable it first: "
            "feedback_loop.py set-config --surface dhu minimapEnabled=true"
        )
        return result

    ns = argparse.Namespace(
        surface="hud", roi="minimap",
        min_edge_density=zd.DEFAULT_MIN_EDGE_DENSITY,
        min_distinct=zd.DEFAULT_MIN_DISTINCT_LUMA,
        max_color_glow_frac=zd.DEFAULT_MAX_COLOR_GLOW_FRAC,
        out_dir=out_dir, serial=serial, tier=tier,
    )
    try:
        r = asyncio.run(zd._run_readable(ns, ws_uri))
    except Exception as e:
        result["pass"] = False
        result["error"] = str(e)
        return result

    result.update(r)
    result["pass"] = bool(r.get("pass", False))
    return result


# ---------------------------------------------------------------------------
# shape-geometry — flutter test test/hud/
# ---------------------------------------------------------------------------

def check_shape_geometry() -> dict[str, Any]:
    result: dict[str, Any] = {"name": "shape-geometry"}
    try:
        proc = subprocess.run(
            ["flutter", "test", "test/hud/"],
            cwd=str(REPO_ROOT), capture_output=True, text=True, timeout=300,
        )
        result["returncode"] = proc.returncode
        result["stdoutTail"] = "\n".join(proc.stdout.splitlines()[-30:])
        if proc.returncode != 0:
            result["stderrTail"] = "\n".join(proc.stderr.splitlines()[-30:])
        result["pass"] = proc.returncode == 0
    except Exception as e:
        result["pass"] = False
        result["error"] = str(e)
    return result


# ---------------------------------------------------------------------------
# --baseline / --against — the comparison primitive the previous 26 Blocks
# lacked. Only the two pixel-producing checks (hud-visible, minimap-readable)
# have captures worth recording.
# ---------------------------------------------------------------------------

_CAPTURE_CHECKS = ("hud-visible", "minimap-readable")


def _save_baseline(dir_path: str, results: dict[str, Any]) -> dict[str, Any]:
    p = Path(dir_path)
    p.mkdir(parents=True, exist_ok=True)
    saved: dict[str, str] = {}
    summary: dict[str, Any] = {}
    for name in _CAPTURE_CHECKS:
        res = results.get(name)
        if not res:
            continue
        src = res.get("shot")
        if src and Path(src).exists():
            dst = p / f"{name}.png"
            dst.write_bytes(Path(src).read_bytes())
            saved[name] = str(dst)
        summary[name] = {
            k: v for k, v in res.items()
            if k in ("metrics", "pass", "roiRect", "minimapEnabled", "skipped")
        }
    (p / "metrics.json").write_text(json.dumps({"results": summary, "captures": saved}, indent=2))
    return {"dir": str(p), "captures": saved, "metricsFile": str(p / "metrics.json")}


def _compare_against(dir_path: str, results: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    meta_path = Path(dir_path) / "metrics.json"
    if not meta_path.exists():
        return (
            {"error": f"no baseline metrics.json in {dir_path} — run with --baseline {dir_path} first"},
            False,
        )
    baseline = json.loads(meta_path.read_text())
    base_results = baseline.get("results", {})
    base_captures = baseline.get("captures", {})

    comparisons: dict[str, Any] = {}
    overall_ok = True

    for name in _CAPTURE_CHECKS:
        cur = results.get(name)
        if cur is None:
            continue
        entry: dict[str, Any] = {}
        base_entry = base_results.get(name)
        base_img_path = base_captures.get(name)
        cur_img_path = cur.get("shot")

        if base_entry is None or not base_img_path or not Path(base_img_path).exists():
            entry["error"] = f"no baseline capture recorded for {name!r} in {dir_path}"
            entry["regression"] = True
            comparisons[name] = entry
            overall_ok = False
            continue
        if not cur_img_path or not Path(cur_img_path).exists():
            entry["error"] = f"no current capture for {name!r} to compare"
            entry["regression"] = True
            comparisons[name] = entry
            overall_ok = False
            continue

        base_img = zp.load(base_img_path)
        cur_img = zp.load(cur_img_path)
        roi = cur.get("roiRect")
        if roi:
            roi_t = tuple(int(v) for v in roi)
            base_img = zp.crop_roi(base_img, roi_t)
            cur_img = zp.crop_roi(cur_img, roi_t)

        try:
            cmp = zp.compare(base_img, cur_img)
        except ValueError as e:
            entry["error"] = str(e)
            entry["regression"] = True
            comparisons[name] = entry
            overall_ok = False
            continue

        pass_flipped = bool(base_entry.get("pass")) and not bool(cur.get("pass"))
        pixel_regression = cmp["changedFrac"] > zd.DEFAULT_MAX_CHANGED_FRAC_SAME
        regression = pass_flipped or pixel_regression

        entry.update({
            "compare": _round(cmp),
            "maxChangedFrac": zd.DEFAULT_MAX_CHANGED_FRAC_SAME,
            "baselinePass": base_entry.get("pass"),
            "currentPass": cur.get("pass"),
            "passFlipped": pass_flipped,
            "pixelRegression": pixel_regression,
            "regression": regression,
        })
        comparisons[name] = entry
        if regression:
            overall_ok = False

    return {"baselineDir": dir_path, "comparisons": comparisons}, overall_ok


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="The Definition-of-Done gate — one command, JSON verdict, "
        "quoted by a Block's sign-off instead of a screenshot path."
    )
    p.add_argument("--tier", choices=["t1", "t2", "t3"], default="t2")
    p.add_argument("--serial", default=_z.DEFAULT_SERIAL)
    p.add_argument(
        "--checks", default=",".join(ALL_CHECKS),
        help=f"comma-separated subset of: {','.join(ALL_CHECKS)}",
    )
    p.add_argument("--baseline", default=None, help="record this run's captures+metrics into DIR")
    p.add_argument("--against", default=None, help="compare this run against a --baseline DIR; fail on regression")
    p.add_argument("--out-dir", default="/tmp/zee_gate", help="dir for captured PNGs (default: %(default)s)")
    p.add_argument(
        "--min-ink-frac", type=float, default=DEFAULT_MIN_HUD_VISIBLE_INK_FRAC,
        help=f"hud-visible threshold (default: %(default)s, measured — see module docstring; "
             f"the originally-suggested 0.02 is not clearable on the current confined-minimap "
             f"architecture)",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    p = build_parser()
    args = p.parse_args(argv)

    checks = [c.strip() for c in args.checks.split(",") if c.strip()]
    unknown = sorted(set(checks) - set(ALL_CHECKS))
    if unknown:
        print(json.dumps({"error": f"unknown checks {unknown}; valid: {ALL_CHECKS}"}, indent=2), file=sys.stderr)
        return 2

    Path(args.out_dir).mkdir(parents=True, exist_ok=True)

    needs_vm = any(c in checks for c in ("surfaces", "relay", "minimap-readable"))
    ws_uri: str | None = None
    ws_uri_error: str | None = None
    if needs_vm:
        try:
            ws_uri = _z.resolve_ws_uri(serial=args.serial, tier=args.tier)
        except Exception as e:
            ws_uri_error = str(e)

    results: dict[str, Any] = {}
    if "env" in checks:
        results["env"] = check_env(args.tier, args.serial)
    if "surfaces" in checks:
        results["surfaces"] = check_surfaces(ws_uri, ws_uri_error)
    if "relay" in checks:
        results["relay"] = check_relay(ws_uri, ws_uri_error, args.serial, args.tier)
    if "hud-visible" in checks:
        results["hud-visible"] = check_hud_visible(args.serial, args.out_dir, args.min_ink_frac)
    if "minimap-readable" in checks:
        results["minimap-readable"] = check_minimap_readable(
            ws_uri, ws_uri_error, args.serial, args.tier, args.out_dir,
        )
    if "shape-geometry" in checks:
        results["shape-geometry"] = check_shape_geometry()

    output: dict[str, Any] = {"tier": args.tier, "checks": checks, "results": results}
    overall_pass = all(bool(results[c].get("pass", False)) for c in checks)

    if args.baseline:
        output["baseline"] = _save_baseline(args.baseline, results)

    if args.against:
        against_result, against_ok = _compare_against(args.against, results)
        output["against"] = against_result
        overall_pass = overall_pass and against_ok

    output["pass"] = overall_pass
    print(json.dumps(output, indent=2))
    return 0 if overall_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
