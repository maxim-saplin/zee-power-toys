---
status: accepted
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
- [x] 0092 (and 0093 as needed) tips prove harness use in FINDINGS (commands + logs, not OCR) — 0092/0093 QA already; this tip banks `tmp/qa/0094-e1791da/`
- [x] Known gaps from SI / agent tips fixed or documented with a recipe — **emu-kill:** `zee_run.py keepalive` (mid-slice `adb get-state`; 2 misses → emu+preflight); hung-install → `down && up`; SI clear gate documented (do not clear emu entry until one full QA slice without death); **stale `$ZEE_VM_URI`:** liveness-probe override like session files (Connect refused on dead port)
- [x] Skill + `feedback_loop.py` recipes match what agents actually run — dump-state needs `--surface`; speedcam-demo positional `on|off`; set-config short aliases `ynaviEnrich`/`alertLaneCams` → dump `*Enabled` keys
- [x] SI app-drive OCR item closed when harness is the default path
- [x] PDM ACCEPT when SI no longer lists app-drive thrash as open — ACCEPT `5d8ee28` (2026-09-23; QA cut + beta four-point + PDM evidence)

## Anti-pattern
Spending multi-turn loops on tesseract / coordinate taps for one-button actions.

## FINDINGS (zee-dev 2026-09-23 tip, base `e1791da`)

Tier T2 / emu-5554 / MBP16. Evidence: `tmp/qa/0094-e1791da/`.

```bash
uv run dev/zee_run.py up --tier t2
# if shell still has a dead ZEE_VM_URI from before up: unset it (or rely on
# post-tip liveness probe) — discovery reads /tmp/zee_vm_uri_t2.txt
uv run dev/feedback_loop.py --tier t2 whoami-all
uv run dev/feedback_loop.py --tier t2 dump-state --surface dhu
# → speedcamConfig present (alertLaneCams, ynaviEnrichEnabled, …)
uv run dev/feedback_loop.py --tier t2 set-config --surface dhu \
  ynaviEnrich=true ynaviAlert=true alertLaneCams=false
uv run dev/feedback_loop.py --tier t2 dump-state --surface dhu
# → ynaviEnrichEnabled true, alertLaneCams false
uv run dev/feedback_loop.py --tier t2 speedcam-demo --surface dhu on
uv run dev/zee_run.py keepalive --tier t2   # action=ok
uv run dev/feedback_loop.py --tier t2 speedcam-demo --surface dhu off
```

No OCR / coordinate taps. Soft improve same tip: `$ZEE_VM_URI` / `--vm-uri`
unreachable → ignore + rediscover (was Connect refused on port from prior session).

## ACCEPT (PDM 2026-09-23)
Tip `5d8ee28` (1.1.0+13). QA independent cut PASS (`tmp/qa/0094-cut-5d8ee28/`);
beta four-point PASS; PDM own evidence PASS. SI Open empty. Soft docstring /
unset-env nits deferred. Harness is the default path; no OCR.
