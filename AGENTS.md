# Agent cold start

Zee Power Toys (and the publish trio with YNavi + Launcher). Treat this as a
live product: preserve working behavior, prove claims on T1/T2/T3, and keep
docs lean.

This file is orientation only. It answers where to work, what to read first,
what never to do, which environment proves a claim, and how to log
self-improvement. Intent and glossary live in `CONTEXT.md` and
`REQUIREMENTS.md`. Procedures live in the owning skill or issue. Do not copy
them here.

## Lean and Clean Docs

Optimize for clarity. Prefer ASD-STE100 tone: short sentences, one idea each.

**Replace first, do not append by default.** Update the owning document in
place and remove superseded statements. Keep a repeat only when it is short,
stable, useful at that point, and linked to its owner. Exact mappings belong
in knowledge docs; current work in `docs/issues/`; durable design in ADRs.
Extract durable rules from incident notes; Git retains the working history.
Review the whole changed section: each addition must improve understanding,
action, or a risk decision.

## What to read first

Read only what the request needs:

- Glossary / product language: `CONTEXT.md`
- Requirements: `REQUIREMENTS.md`
- Issue queue: `docs/issues/` (numbered files; do not invent a second tracker)
- App drive / Feedback Loop: `.agents/skills/drive-zee-app/SKILL.md`
- Feedback Loop contract: `docs/feedback-loop-contract.md`
- Self-improvement inbox: `SI.md` (this file's SI section below)

If working a numbered issue, read that issue first.

## Communication Discipline

**Lead with the answer.** First line = decision, number, command, or next action.

**Pick a mode:**
- **CHAT** = conversation UI. Default 1 short paragraph or 3-5 bullets.
- **ARTIFACT** = file, PR, commit, plan, ADR, runbook, or report. Self-contained.

**Caveats earn their place.** Include only if ignoring the caveat changes the
recommendation, the next step, or the risk.

**Self-test:** If the first sentence is not the answer, rewrite it.

## Where to work

- **T1** — Linux desktop fakes (`uv run dev/zee_run.py up`). Fastest Dart loop.
  Not available as a Mac host runner.
- **T2** — Android emulator Tablet_12L / DHU-sized (`up --tier t2`). Truth tier
  for native edge, Overlay, HUD geometry simulation.
- **T3** — Zeekr car DHU. Real AdaptAPI, real HUD optics. Use only when T2
  cannot prove the claim.
- **Publish trio** — `zee-power-toys`, `ynavi-zee`, `zeekr_apk_mod`. Releases
  via GitHub Releases, not files dropped in `.git`.

State the proof environment in every result: T1, T2, or T3.

## What never to do

- Do not claim ACCEPT without your own double-check of evidence (screenshots,
  logs, paired before/after). Do not rubber-stamp tips alone.
- Do not drive the app with blind OCR / coordinate taps when
  `ext.zee.*` or ValueKey paths exist. Prefer
  `.agents/skills/drive-zee-app/SKILL.md`.
- Do not keep burning turns on a broken harness or a dead emulator. Pause the
  product slice, fix or escalate the control surface, then resume (see SI).
- Do not use Mac window screenshots for README/product proof. Use Tablet emu
  (DHU size) frames only.
- Do not invent a second issue tracker or a parallel "notes" doc for open work.
- Do not print secrets in chat or logs.

## Which environment proves the claim

| Claim                         | Proof                                      |
|-------------------------------|--------------------------------------------|
| Dart logic / pure UI          | T1 or `flutter test`                       |
| Native / Overlay / density    | T2 runtime + screenshot                    |
| HUD optics / AdaptAPI         | T3 car session                             |
| Geometry parity (HUD/DHU/OV)  | Paired T2 (or T3) crops of all three views |
| Release / install             | GH Actions + install smoke on T2/T3        |

## Log self-improvement items

When you hit friction that is not worth diverting the main slice to fix, or a
larger process / design / harness gap, record it in `SI.md`. Create the file if
it does not exist. Maintain entries in this format:

```
## YYYY-MM-DD HH:MM — <short name> -
<What you were doing> → <what to improve / improved>. Include a possible cause
or fix when useful.
```

Rules:

- Log SI items **proactively when they occur**, but do not interrupt the main
  task to rewrite the world mid-slice.
- Do not add duplicate entries.
- Distinct from completed-work logs, real product bugs (`docs/issues/`), and
  ADRs. The goal is a lessons-learned body and alignment with the user on how
  to improve the process or the system.
- Typical use: end of a larger session, or the moment a repeated blocker shows
  up (same harness failure twice, emu dead again, Maxim had to ask you to
  pause and fix infrastructure).
- When the same friction repeats, **act**: open or update an issue, harden the
  skill/script, or pause QA and fix the control surface — do not wait for the
  user to name it.
