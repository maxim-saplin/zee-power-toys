# Self-improvement inbox

> Keep this empty. When you hit friction twice in a session, log it here, then
> either fix harness/infra the same slice or file a ticket and clear the entry
> when the tip lands. Product work waits on repeated harness failure.

## Open

## 2026-09-29 15:18 — T2 platform-signed install mismatch -
Toys `1.1.0+31` passed release CI, but install smoke failed on both Android 12L
AVDs with `INSTALL_FAILED_SHARED_USER_INCOMPATIBLE`: their system certificates
do not match the committed car platform key for `android.uid.system`. YNavi
v30 installs on T2. Use a T2 image signed with the matching platform key or
reserve this release-install smoke for T3; do not uninstall debug QA state to
force the test.

## Cleared

### App-drive OCR / tap thrash (2026-09-22) — cleared 2026-09-23
Harness is the default path on tip after 0094 FINDINGS (`e1791da`+): `dump-state`
shows `speedcamConfig`; `set-config` aliases (`ynaviEnrich`/`alertLaneCams`)
echo; `speedcam-demo on|off` one-shot; `zee_run keepalive`. Soft: stale
`$ZEE_VM_URI` now liveness-probed like session files. Prefer skill recipes —
no OCR / guessed taps for one-button Demo/Overlay/config.


### Emulator killed / unstable mid-QA (2026-09-22) — cleared 2026-09-23
Clear gate met: QA 0092+0093 slice on `c844baa` pulsed `keepalive --tier t2`
with all `action=ok` and no mid-slice emu death (PDM 2026-09-23). Keepalive tip
`334108b` + soft nits (crashpad rmtree, `adb -s wait-for-device`) on this tip.

### Overlay SYSTEM_ALERT_WINDOW GONE (2026-09-22 23:55) — cleared 2026-09-23
Root: `_pushSpeedcamSystemOverlay` re-ran presence after danger resolved;
`approach` defaulted `headingDeg=0`. Fixed same session (tip e6ec100+). Removed
from open inbox.
