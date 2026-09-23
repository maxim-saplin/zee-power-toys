---
status: open
labels: [agent, harness, dx, si]
created: 2026-09-23
satisfies: foundation
blocked-by: []
modules: [drive-zee-app skill, ext.zee, feedback_loop.py]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
parent: 0089
---

# 0094 — App-drive harness: use, tinker, improve, close

## Block scope
0089 shipped `speedcam-demo on|off` / one RPC (`081431f`) and was ACCEPTed. Maxim 2026-09-23: **get it used** — file this follow-on to specifically **use**, **tinker**, **improve**, and **close**.

## Intent
- Team must drive Speedcam Demo / Overlay / config via the harness on every 0092+ slice (no OCR / guessed taps).
- While using it, log friction to SI.md; if the same friction repeats, pause product work and harden the skill/script.
- Expand coverage where agents still thrash (setConfig aliases, tapByKey gaps, preflight, map preview drive for 0093, etc.).

## Definition of Done
- [ ] 0092 (and 0093 as needed) tips prove harness use in FINDINGS (commands + logs, not OCR)
- [ ] Known gaps from SI / agent tips fixed or documented with a recipe
- [ ] Skill + `feedback_loop.py` recipes match what agents actually run
- [ ] SI app-drive OCR item closed when harness is the default path
- [ ] PDM ACCEPT when SI no longer lists app-drive thrash as open

## Anti-pattern
Spending multi-turn loops on tesseract / coordinate taps for one-button actions.
