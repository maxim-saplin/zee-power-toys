#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""ynavi_prep.py — one command to get the real YNavi map ready on the T2 HUD.

Getting the real YNavi cluster map onto the T2 emulator HUD is a manual,
easy-to-get-wrong sequence: install the *modded* APK (stock YNavi silently
fails to render — see below), reset its session state, re-grant permissions
`pm clear` wipes, and confirm the mod is actually detectable — all *before*
`zee_run.py up`, because steps 3-4 here conflict with a live Flutter session.

Background reading (do this before debugging a failure):
  docs/knowledge/phase0-ynavi-ab-testing.md   reset sequence + why only one
                                               CarApp host may bind at a time
  docs/knowledge/ynavi-bind-and-mod.md        patch inventory — P9 (HasPlus)
                                               is mandatory or bind succeeds
                                               with a silent no-map
  docs/issues/0019-ynavi-map-render.md        the working render recipe

Ordering (non-negotiable):
  1. Refuse to run if a live T2 (or any zee_run.py) session is present.
  2. Install the modded APK.
  3. am force-stop ru.yandex.yandexnavi + com.zeepowertoys.zee_power_toys,
     pm clear ru.yandex.yandexnavi.
  4. pm grant ACCESS_FINE_LOCATION + ACCESS_COARSE_LOCATION (pm clear wipes
     runtime grants).
  5. Verify the mod is detectable: pm dump | grep NavigationCarAppService
     (mirrors MainActivity.kt's isYnaviAvailable() without needing the app up).
  6. Print the exact next commands — including the easy-to-forget one:
     minimap.enabled defaults to false, so the map will not appear until
     `minimapEnabled=true` is set via the Feedback Loop.
  7. --verify chains: prep → zee_run.py up --tier t2 → enable the minimap →
     shot --layer native → report whether YNavi is reachable and a map PNG
     was produced (a human/agent must still look at the PNG to confirm a
     map is actually visible — this script cannot "see").

Usage
  uv run dev/ynavi_prep.py [--serial emulator-5554] [--apk PATH]
                           [--via-app] [--skip-install] [--verify]

--apk PATH        explicit modded APK to install (skips auto-discovery)
--skip-install    skip step 2 entirely (assume already installed)
--via-app         drive `ext.zee.install target=ynavi` through an ALREADY
                   LIVE session instead of `adb install`. This is a secondary,
                   documented-but-discouraged path: it requires the very
                   live session step 1 refuses to run alongside. When used,
                   this script performs ONLY the install and then tells you
                   to stop the session and re-run with --skip-install to
                   finish steps 3-6.
--verify          after prep, bring up T2, enable the minimap, and capture
                   /tmp/ynavi-verify.png (native composite, expect 1024x576)

Idempotent and re-runnable: every step is safe to repeat.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SERIAL = os.environ.get("ADB_SERIAL", "emulator-5554")

YNAVI_PKG = "ru.yandex.yandexnavi"
ZEE_PKG = "com.zeepowertoys.zee_power_toys"
YNAVI_SERVICE_SUFFIX = "NavigationCarAppService"

_T1_PID_FILE = Path("/tmp/zee_run_t1.pid")
_T2_PID_FILE = Path("/tmp/zee_run_t2.pid")
# Per-tier session URI files (QA3-5 fix — zee_run.py no longer writes one
# shared /tmp/zee_vm_uri.txt; see dev/zee_drive.py's vm_uri_file()).
_VM_URI_FILES = [Path("/tmp/zee_vm_uri_t1.txt"), Path("/tmp/zee_vm_uri_t2.txt")]
_VERIFY_SHOT = Path("/tmp/ynavi-verify.png")

# Sibling-clone conventions per lib/services/install_targets.dart:23-27
# (repo maxim-saplin/ynavi-zee, branch speedcam, modded_apks/zeekr_signed_v11.apk).
# Checked at multiple plausible clone locations since the branch actually
# checked out locally may differ (e.g. "hud") — we only care that the file
# is materialized on disk, not which branch produced it.
_APK_REL_PATH = Path("modded_apks/zeekr_signed_v11.apk")
_APK_CANDIDATES = [
    REPO_ROOT.parent / "ynavi-zee" / _APK_REL_PATH,       # sibling clone (this machine)
    Path.home() / "src" / "ynavi-zee" / _APK_REL_PATH,
    Path("/home/user/src/ynavi-zee") / _APK_REL_PATH,     # docs-reference path (other hosts)
]
MIN_APK_BYTES = 1_000_000  # guard against un-pulled git-lfs pointer stubs


def _print_cmd(cmd: list[str]) -> None:
    print(f"$ {' '.join(str(c) for c in cmd)}")


def _adb(serial: str, *args: str, timeout: int = 60) -> subprocess.CompletedProcess:
    cmd = ["adb", "-s", serial, *args]
    _print_cmd(cmd)
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if r.stdout.strip():
        print(r.stdout.rstrip())
    if r.stderr.strip():
        print(r.stderr.rstrip(), file=sys.stderr)
    return r


def _run_dev_tool(*args: str, timeout: int = 180) -> subprocess.CompletedProcess:
    """Run one of the sibling dev/*.py tools via `uv run`, same convention as docs."""
    cmd = ["uv", "run", *args]
    _print_cmd(cmd)
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=REPO_ROOT, timeout=timeout)
    if r.stdout.strip():
        print(r.stdout.rstrip())
    if r.stderr.strip():
        print(r.stderr.rstrip(), file=sys.stderr)
    return r


# ---------------------------------------------------------------------------
# Step 1 — guard: refuse if a live session is present.
# ---------------------------------------------------------------------------

def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True  # process exists, just not ours
    return True


def check_live_session() -> list[str]:
    """Return non-empty list of reasons a live zee_run.py session was detected."""
    reasons: list[str] = []
    if _T2_PID_FILE.exists():
        raw = _T2_PID_FILE.read_text().strip()
        try:
            pid = int(raw)
        except ValueError:
            pid = None
        if pid is not None and _pid_alive(pid):
            reasons.append(
                f"{_T2_PID_FILE} present and pid={pid} is running — a live T2 "
                f"`flutter run` session exists."
            )
    for f in _VM_URI_FILES:
        if f.exists():
            reasons.append(
                f"{f} present — a zee_run.py session URI is persisted "
                f"(this file is only removed by `zee_run.py down`)."
            )
    return reasons


def guard_or_die(serial: str) -> int | None:
    reasons = check_live_session()
    if not reasons:
        return None
    print("[ynavi_prep] REFUSING TO RUN — a live session was detected:", file=sys.stderr)
    for r in reasons:
        print(f"  - {r}", file=sys.stderr)
    print(
        "\n  Steps 3-4 of this script (`am force-stop`, `pm clear` against "
        f"{YNAVI_PKG}, and `am force-stop {ZEE_PKG}`) will kill a live "
        "`flutter run` session and cost a 60-90s rebuild (SKILL.md hazard #2).\n"
        "\n  Remedy:\n"
        "    uv run dev/zee_run.py down --tier t2\n"
        "  then re-run this script.\n",
        file=sys.stderr,
    )
    return 1


# ---------------------------------------------------------------------------
# Step 2 — install the modded APK.
# ---------------------------------------------------------------------------

def find_local_apk() -> Path | None:
    for p in _APK_CANDIDATES:
        if p.exists() and p.is_file() and p.stat().st_size >= MIN_APK_BYTES:
            return p
    return None


def is_installed(serial: str) -> bool:
    r = _adb(serial, "shell", "pm", "path", YNAVI_PKG)
    return r.returncode == 0 and "package:" in r.stdout


def install_apk(serial: str, apk_path: Path) -> bool:
    size_mb = apk_path.stat().st_size / 1_000_000
    print(f"[ynavi_prep] installing modded YNavi: {apk_path} ({size_mb:.1f} MB)")
    r = _adb(serial, "install", "-r", str(apk_path), timeout=180)
    combined = r.stdout + r.stderr
    if "Success" in combined:
        return True
    if "INSTALL_FAILED_VERSION_DOWNGRADE" in combined:
        print("[ynavi_prep] version downgrade — retrying with -d")
        r = _adb(serial, "install", "-r", "-d", str(apk_path), timeout=180)
        combined = r.stdout + r.stderr
        if "Success" in combined:
            return True
    if "INSTALL_FAILED_UPDATE_INCOMPATIBLE" in combined or "signatures do not match" in combined.lower():
        print(f"[ynavi_prep] signature mismatch with existing install — uninstalling {YNAVI_PKG} first")
        _adb(serial, "uninstall", YNAVI_PKG)
        r = _adb(serial, "install", "-r", str(apk_path), timeout=180)
        combined = r.stdout + r.stderr
        if "Success" in combined:
            return True
    print(f"[ynavi_prep] install FAILED — adb output above.", file=sys.stderr)
    return False


def cmd_install(serial: str, apk_arg: str | None) -> tuple[bool, str]:
    """Returns (ok, detail-message)."""
    if apk_arg:
        p = Path(apk_arg).expanduser()
        if not p.exists():
            return False, f"--apk {p} does not exist"
        return install_apk(serial, p), f"--apk {p}"

    p = find_local_apk()
    if p is None:
        checked = "\n".join(f"    - {c}" for c in _APK_CANDIDATES)
        detail = (
            "No modded YNavi APK found and none was given via --apk.\n"
            "  Per lib/services/install_targets.dart:23-27 the published coordinates are:\n"
            "    repo=maxim-saplin/ynavi-zee branch=speedcam path=modded_apks/zeekr_signed_v11.apk\n"
            "  Checked for a local clone at:\n"
            f"{checked}\n"
            "  None of these exist (or are un-pulled git-lfs pointer stubs < "
            f"{MIN_APK_BYTES} bytes).\n"
            "  To finish: clone maxim-saplin/ynavi-zee, `git lfs pull` the asset, "
            "and pass --apk <path>, or drive the download live via --via-app "
            "(needs a running session — see --via-app docs above)."
        )
        return False, detail
    return install_apk(serial, p), f"auto-discovered: {p}"


# ---------------------------------------------------------------------------
# Step 3+4 — reset YNavi session state, stop competing host, re-grant perms.
# ---------------------------------------------------------------------------

def reset_and_grant(serial: str) -> None:
    print(f"\n[ynavi_prep] step 3 — reset session state + stop competing CarApp host")
    _adb(serial, "shell", "am", "force-stop", YNAVI_PKG)
    _adb(serial, "shell", "pm", "clear", YNAVI_PKG)
    _adb(serial, "shell", "am", "force-stop", ZEE_PKG)

    print(f"\n[ynavi_prep] step 4 — re-grant location permissions (pm clear wiped them)")
    _adb(serial, "shell", "pm", "grant", YNAVI_PKG, "android.permission.ACCESS_FINE_LOCATION")
    _adb(serial, "shell", "pm", "grant", YNAVI_PKG, "android.permission.ACCESS_COARSE_LOCATION")


# ---------------------------------------------------------------------------
# Step 5 — verify the mod is detectable (mirrors MainActivity.kt:647-676).
# ---------------------------------------------------------------------------

def verify_mod_detectable(serial: str) -> bool:
    print(f"\n[ynavi_prep] step 5 — verify {YNAVI_SERVICE_SUFFIX} is declared (mirrors isYnaviAvailable())")

    # IMPORTANT gotcha found via live testing on this emulator: `pm dump <pkg>`
    # does NOT cleanly filter to just that package — it appends system-wide
    # process-stats/battery-stats history sections that mention ANY process
    # that ever ran under that name, even long after the package was
    # uninstalled. Grepping that output alone gives a FALSE POSITIVE for an
    # absent package. So: gate on `pm path` (definitive "is it installed right
    # now" signal) FIRST, and only trust the grep when that gate passes.
    if not is_installed(serial):
        print(
            f"[ynavi_prep] NOT DETECTED — {YNAVI_PKG} is not installed on {serial} "
            "(`pm path` returned nothing). Not running the pm dump grep: on this "
            "device `pm dump <pkg>` for an absent package still surfaces "
            f"{YNAVI_SERVICE_SUFFIX} from stale historical process-stats residue "
            "of a PREVIOUS install — a real false positive we hit while building "
            "this script. Install the mod first.",
            file=sys.stderr,
        )
        return False

    pipeline = f"pm dump {YNAVI_PKG} | grep -i {YNAVI_SERVICE_SUFFIX}"
    r = _adb(serial, "shell", pipeline)
    found = bool(r.stdout.strip())
    if found:
        print(f"[ynavi_prep] DETECTED — {YNAVI_SERVICE_SUFFIX} is declared and exported.")
    else:
        print(
            f"[ynavi_prep] NOT DETECTED — {YNAVI_PKG} is installed but "
            f"{YNAVI_SERVICE_SUFFIX} did not show up in `pm dump {YNAVI_PKG}`. "
            "The installed build is likely stock YNavi (not the modded APK) "
            "and lacks the service, or the service declaration is malformed.",
            file=sys.stderr,
        )
    return found


# ---------------------------------------------------------------------------
# Step 6 — print the exact next commands.
# ---------------------------------------------------------------------------

def print_next_steps() -> None:
    print(
        "\n[ynavi_prep] step 6 — next commands\n"
        "\n  1. Bring up T2 (must run AFTER this script, never before):\n"
        "       uv run dev/zee_run.py up --tier t2\n"
        "\n  2. EASY TO FORGET: minimap.enabled is false by default in persisted\n"
        "     config (lib/services/config_store.dart MinimapConfig(enabled: false)).\n"
        "     The map will not appear until you flip it via the Feedback Loop:\n"
        "       uv run dev/feedback_loop.py set-config --surface dhu minimapEnabled=true\n"
        "\n  3. Prove the map actually renders — the native composite, never the\n"
        "     bare Flutter layer (docs/issues/0009-minimap-under-layer.md:39):\n"
        "       uv run dev/feedback_loop.py shot --surface hud --layer native \\\n"
        "           --out /tmp/ynavi-verify.png --expect 1024x576\n"
        "\n  4. Confirm YNavi availability in the app's own view-model:\n"
        "       uv run dev/feedback_loop.py read-view-model --surface dhu\n"
        "       (check .minimap.ynaviAvailable == true and .minimap.enabled == true)\n"
    )


# ---------------------------------------------------------------------------
# --via-app — secondary path: drive the install through a LIVE session.
# ---------------------------------------------------------------------------

def cmd_via_app(serial: str) -> int:
    print(
        "[ynavi_prep] --via-app requested.\n"
        "  This drives `ext.zee.install target=ynavi` through an ALREADY-LIVE\n"
        "  session — the same kind of session step 1's guard exists to protect.\n"
        "  This is intentionally treated as a documented-but-secondary path:\n"
        "  it performs ONLY the install here. It does NOT run steps 3-6 (which\n"
        "  force-stop/pm-clear/grant) because those would tear down the very\n"
        "  session used to drive the install.\n"
    )
    if not any(f.exists() for f in _VM_URI_FILES) and "ZEE_VM_URI" not in os.environ:
        print(
            "[ynavi_prep] no live session found (no /tmp/zee_vm_uri_{t1,t2}.txt, "
            "no $ZEE_VM_URI). Start one first:\n"
            "    uv run dev/zee_run.py up --tier t2\n"
            "  then re-run with --via-app.",
            file=sys.stderr,
        )
        return 1

    r = _run_dev_tool(
        "dev/zee_drive.py", "call", "ext.zee.install",
        "--isolate", "dhu", "target=ynavi",
    )
    if r.returncode != 0:
        print("[ynavi_prep] ext.zee.install call failed.", file=sys.stderr)
        return 1

    print("[ynavi_prep] polling install progress via read-view-model …")
    deadline = time.monotonic() + 180.0
    phase = None
    while time.monotonic() < deadline:
        rv = _run_dev_tool("dev/feedback_loop.py", "read-view-model", "--surface", "dhu")
        # Output is pretty-printed (multi-line) JSON — parse the whole blob.
        try:
            data = json.loads(rv.stdout) if rv.stdout.strip() else {}
        except json.JSONDecodeError:
            data = {}
        install = data.get("install") or {}
        phase = install.get("phase")
        print(f"[ynavi_prep] install.phase={phase} fraction={install.get('fraction')}")
        if phase in ("done", "failed"):
            break
        time.sleep(2.0)

    if phase != "done":
        print(f"[ynavi_prep] install did not reach 'done' (last phase={phase}).", file=sys.stderr)
        return 1

    print(
        "\n[ynavi_prep] install done. Now stop the session and finish the rest:\n"
        "    uv run dev/zee_run.py down --tier t2\n"
        "    uv run dev/ynavi_prep.py --skip-install\n"
    )
    return 0


# ---------------------------------------------------------------------------
# --verify — chain: prep already ran → up → enable minimap → shot → assert.
# ---------------------------------------------------------------------------

def cmd_verify(serial: str) -> int:
    print("\n[ynavi_prep] --verify — bringing up T2 …")
    r = _run_dev_tool("dev/zee_run.py", "up", "--tier", "t2", timeout=180)
    if r.returncode != 0:
        print("[ynavi_prep] zee_run.py up --tier t2 FAILED — see output above.", file=sys.stderr)
        return 1

    print("\n[ynavi_prep] --verify — enabling the minimap …")
    r = _run_dev_tool(
        "dev/feedback_loop.py", "set-config", "--surface", "dhu", "minimapEnabled=true",
    )
    if r.returncode != 0:
        print("[ynavi_prep] set-config minimapEnabled=true FAILED.", file=sys.stderr)
        return 1

    # Give the native minimap host a moment to (re)bind after the config write.
    time.sleep(2.0)

    print("\n[ynavi_prep] --verify — capturing native composite …")
    r = _run_dev_tool(
        "dev/feedback_loop.py", "shot", "--surface", "hud", "--layer", "native",
        "--out", str(_VERIFY_SHOT), "--expect", "1024x576",
    )
    shot_ok = r.returncode == 0 and _VERIFY_SHOT.exists()
    if not shot_ok:
        print(f"[ynavi_prep] shot capture FAILED or dimension mismatch — see output above.", file=sys.stderr)

    print("\n[ynavi_prep] --verify — reading view-model for YNavi availability …")
    r = _run_dev_tool("dev/feedback_loop.py", "read-view-model", "--surface", "dhu")
    ynavi_available = None
    minimap_enabled = None
    if r.returncode == 0 and r.stdout.strip():
        # Output is pretty-printed (multi-line) JSON — parse the whole blob,
        # not just the last line (that line alone is just "}").
        try:
            data = json.loads(r.stdout)
            mm = data.get("minimap") or {}
            ynavi_available = mm.get("ynaviAvailable")
            minimap_enabled = mm.get("enabled")
        except json.JSONDecodeError:
            pass

    print(
        f"\n[ynavi_prep] --verify summary:\n"
        f"  shot written:     {shot_ok} → {_VERIFY_SHOT}\n"
        f"  minimap.enabled:  {minimap_enabled}\n"
        f"  minimap.ynaviAvailable: {ynavi_available}\n"
        "  NOTE: this script cannot determine whether a map is visually\n"
        "  rendered in the PNG — inspect it directly before claiming success.\n"
    )

    if not shot_ok or ynavi_available is not True:
        return 1
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="One-command prep for the real YNavi map on the T2 HUD.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--serial", default=DEFAULT_SERIAL, help="adb serial (default: %(default)s)")
    p.add_argument("--apk", default=None, help="path to the modded YNavi APK (skip auto-discovery)")
    p.add_argument("--via-app", action="store_true",
                    help="install via ext.zee.install through an already-live session (secondary path)")
    p.add_argument("--skip-install", action="store_true", help="skip step 2 (assume already installed)")
    p.add_argument("--verify", action="store_true",
                    help="after prep, bring up T2, enable the minimap, and capture a native shot")
    args = p.parse_args(argv)

    if args.via_app:
        return cmd_via_app(args.serial)

    # Step 1 — non-negotiable guard.
    blocked = guard_or_die(args.serial)
    if blocked is not None:
        return blocked

    # Step 2 — install.
    if args.skip_install:
        print("[ynavi_prep] --skip-install: skipping step 2")
        if not is_installed(args.serial):
            print(
                f"[ynavi_prep] WARNING: {YNAVI_PKG} is not installed on {args.serial}; "
                "steps 3-5 below will be no-ops.",
                file=sys.stderr,
            )
    else:
        print(f"\n[ynavi_prep] step 2 — install modded YNavi APK")
        ok, detail = cmd_install(args.serial, args.apk)
        if not ok:
            print(f"\n[ynavi_prep] STEP 2 BLOCKED:\n{detail}", file=sys.stderr)
            print(
                "\n[ynavi_prep] Nothing destructive was done. Steps 3-6 were not run. "
                "Re-run with --apk <path> or --skip-install once the APK is available.",
                file=sys.stderr,
            )
            return 2
        print(f"[ynavi_prep] install OK ({detail})")

    # Step 3+4 — reset + grant.
    reset_and_grant(args.serial)

    # Step 5 — verify detectability.
    detected = verify_mod_detectable(args.serial)

    # Step 6 — print next commands.
    print_next_steps()

    if not args.verify:
        return 0 if detected else 1

    if not detected:
        print(
            "[ynavi_prep] --verify requested but the mod was not detected in step 5 — "
            "proceeding anyway to produce diagnostic output, but the map is very "
            "unlikely to render.",
            file=sys.stderr,
        )

    rc = cmd_verify(args.serial)
    return rc if detected else 1


if __name__ == "__main__":
    raise SystemExit(main())
