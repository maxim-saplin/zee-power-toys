---
status: ready-for-agent
labels: [agent, harness, dx]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [drive-zee-app skill, ext.zee, ValueKey]
tier: T2
owner: zee-dev
priority: next
filed-by: zee-pdm
---

# 0089 — Agent app-drive harness (stop OCR/tap thrash)

## Block scope
Agents wasted many turns enabling Speedcam HUD Demo / Overlay via OCR + coordinate taps; uiautomator idle dumps flaked. Maxim: control surface is horrible — fix skill/harness so agents do not burn turns on simple app use.

## Direction
Prefer `ext.zee.tapByKey` / `ext.zee.setConfig` / ValueKeys via `.agents/skills/drive-zee-app/SKILL.md` over tesseract and guessed taps.

## Definition of Done
- [ ] Reliable one-command (or short recipe) to force Demo + Overlay ON/OFF without OCR
- [ ] Skill updated; SI.md notes the anti-pattern
- [ ] QA uses harness for next Overlay/Demo cuts without pixel guessing
