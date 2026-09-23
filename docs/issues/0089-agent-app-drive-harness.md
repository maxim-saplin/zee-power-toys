---
status: qa-pass
labels: [agent, harness, dx]
created: 2026-09-22
tipped: 2026-09-23
satisfies: foundation
blocked-by: []
modules: [drive-zee-app skill, ext.zee, ValueKey]
tier: T2
owner: zee-dev
priority: next
filed-by: zee-pdm
tip: 081431f
accepted: 2026-09-23
evidence: tmp/qa/0089-cut/
---

# 0089 — Agent app-drive harness (stop OCR/tap thrash)

## Block scope
Agents wasted many turns enabling Speedcam HUD Demo / Overlay via OCR + coordinate taps; uiautomator idle dumps flaked. Maxim: control surface is horrible — fix skill/harness so agents do not burn turns on simple app use.

## Direction
Prefer `ext.zee.speedcam` / `ext.zee.setConfig` / `ext.zee.tapByKey` / ValueKeys via `.agents/skills/drive-zee-app/SKILL.md` over tesseract and guessed taps.

## Tip (2026-09-23)
Highest-value incremental fix — not a rewrite:

1. **`ext.zee.speedcam action=demo|demoStop`** — mirrors Settings HUD Demo
   (pose + 50 km/h; fake-cam fallback). Optional **`overlay=true|false`**
   flips `SpeedcamConfig.dhuSystemOverlay` in the same RPC.
2. **`feedback_loop.py speedcam-demo on|off`** — one-command recipe for QA/agents.
3. **`setConfig` accepts `overlay=`** alias for `dhuSystemOverlay`.
4. **Skill + SI** document the recipe and the OCR anti-pattern.

### How to use
```bash
uv run dev/feedback_loop.py speedcam-demo on    # Demo + Overlay
uv run dev/feedback_loop.py speedcam-demo off
# raw:
uv run dev/zee_drive.py call ext.zee.speedcam --isolate dhu action=demo overlay=true
```

UI fallback keys: `nav-speedcam`, `speedcam-dhu-system-overlay`, `speedcam-hud-demo`, `speedcam-hud-demo-stop`.

## Definition of Done
- [x] Reliable one-command (or short recipe) to force Demo + Overlay ON/OFF without OCR
- [x] Skill updated; SI.md notes the anti-pattern
- [ ] QA uses harness for next Overlay/Demo cuts without pixel guessing

## ACCEPT notes
QA PASS 2026-09-23 — speedcam-demo on|off Demo+Overlay; awaiting PDM ACCEPT for 1.1.0.
Evidence: `tmp/qa/0089-cut/`
