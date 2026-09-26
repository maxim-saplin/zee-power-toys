---
status: open
labels: [install, update, ux]
created: 2026-09-26
satisfies: Install screen auto-checks Toys version on open (no tap)
tier: T2
owner: zee-dev
blocked-by: []
modules: [Install / Update screen, version check]
priority: now
filed-by: zee-pdm
related: [0103]
parent: [0103]
gate: armed-2026-09-26
---

# 0115 — Install screen: auto-check Toys version on open

## Block scope

Maxim 2026-09-26 ~13:12 Minsk: when opening the **install** screen, **auto-check for a new Zee Power Toys version** the same way other items on that screen already refresh — **no button tap** required.

## Product rules

1. On screen open / resume: kick the Toys version check automatically (parity with sibling rows).
2. Manual refresh control may remain; it must not be the only path.
3. EN/RU copy unchanged unless a one-line “checking…” state is needed.
4. Fail soft (offline / GH rate) — show last known + error, don’t hang forever.

## DoD (T2)

- [ ] Open install screen → Toys version check starts without tap
- [ ] Other rows still behave as today
- [ ] Soft: offline path

## Soft / residuals

- YNavi / Launcher already auto? Match their cadence; don’t regress 0103 Update vs Reinstall wording.
