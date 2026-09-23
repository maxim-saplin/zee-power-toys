# Self-improvement inbox

> Keep this empty. When you hit friction twice in a session, log it here, then
> either fix harness/infra the same slice or file a ticket and clear the entry
> when the tip lands. Product work waits on repeated harness failure.

## Open

### Emulator killed / unstable mid-QA (2026-09-22)
QA burned turns while Tablet_12L died (`adb: no devices/emulators found`).
**Rule:** after two emu/adb failures in a session, stop the product tip, stabilize
T2 (restart emu, keepalive, `zee_run.py preflight`), post the blocker, then
resume. Harden preflight + pulse T2 health; treat repeated death as SI →
script/skill, not noise.
**Owner:** zee-dev + zee-qa · **Clear when:** preflight/keepalive tip on main and
team proves a slice without mid-QA emu death.

### App-drive OCR / tap thrash (2026-09-22) → see 0094
0089 tipped `speedcam-demo` / one RPC. Follow-on **0094** is to *use*, tinker,
improve, and close. Prefer `ext.zee` / `feedback_loop.py` /
`.agents/skills/drive-zee-app/SKILL.md`. Clear this entry when 0094 ACCEPTs.

## Cleared

### Overlay SYSTEM_ALERT_WINDOW GONE (2026-09-22 23:55) — cleared 2026-09-23
Root: `_pushSpeedcamSystemOverlay` re-ran presence after danger resolved;
`approach` defaulted `headingDeg=0`. Fixed same session (tip e6ec100+). Removed
from open inbox.
