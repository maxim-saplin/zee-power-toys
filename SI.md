# Self-improvement inbox

## 2026-09-22 23:40 — Emulator killed / unstable mid-QA -
QA burned turns on Overlay / CRT cuts while Tablet_12L repeatedly died
(`adb: no devices/emulators found`). Maxim had to tell the team to pause and
fix emu stability instead of the product slice. → When emu / adb / launch
harness fails twice in a session, **stop the product tip**, diagnose and
stabilize T2 (restart emu, keepalive, preflight), post the blocker, then
resume. Do not keep retrying installs on a dead device hoping it recovers.
Possible fix: harden `zee_run.py preflight` + a standing "T2 health" check in
the delivery pulse; treat repeated emu death as an SI → skill/script change,
not background noise.

## 2026-09-22 23:40 — App drive via OCR / coordinate taps -
Agents failed to enable Speedcam HUD Demo and Overlay reliably using tesseract
OCR and guessed taps; uiautomator idle dumps also flaked. → Prefer
`ext.zee.tapByKey` / `ext.zee.setConfig` / ValueKeys via
`.agents/skills/drive-zee-app/SKILL.md`. Tracked as product/process issue
`docs/issues/0089-agent-app-drive-harness.md`. Until that lands, do not spend
a multi-turn loop on blind UI guessing for a one-button action.
