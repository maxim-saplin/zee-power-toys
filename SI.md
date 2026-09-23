# Self-improvement inbox

> Keep this empty. When you hit friction twice in a session, log it here, then
> either fix harness/infra the same slice or file a ticket and clear the entry
> when the tip lands. Product work waits on repeated harness failure.

## Open

### App-drive OCR / tap thrash (2026-09-22) → see 0094
0089 tipped `speedcam-demo` / one RPC. Follow-on **0094** is to *use*, tinker,
improve, and close. Prefer `ext.zee` / `feedback_loop.py` /
`.agents/skills/drive-zee-app/SKILL.md`. Clear this entry when 0094 ACCEPTs.

## Cleared

### Emulator killed / unstable mid-QA (2026-09-22) — cleared 2026-09-23
Clear gate met: QA 0092+0093 slice on `c844baa` pulsed `keepalive --tier t2`
with all `action=ok` and no mid-slice emu death (PDM 2026-09-23). Keepalive tip
`334108b` + soft nits (crashpad rmtree, `adb -s wait-for-device`) on this tip.

### Overlay SYSTEM_ALERT_WINDOW GONE (2026-09-22 23:55) — cleared 2026-09-23
Root: `_pushSpeedcamSystemOverlay` re-ran presence after danger resolved;
`approach` defaulted `headingDeg=0`. Fixed same session (tip e6ec100+). Removed
from open inbox.
