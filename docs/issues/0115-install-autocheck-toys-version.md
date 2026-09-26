---
status: accepted
tip: 77a8b76
accepted: 2026-09-26
evidence: tmp/qa/0115-cut-77a8b76/
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

- [x] Open install screen → Toys version check starts without tap
- [x] Other rows still behave as today
- [x] Soft: offline path
- [x] QA dens320 + four-point + PDM ACCEPT — PASS / ACCEPT `77a8b76` (2026-09-26). Soft: car T3 Checking…→result.

## Soft / residuals

- YNavi / Launcher already auto? Match their cadence; don’t regress 0103 Update vs Reinstall wording.
- Soft: car T2/T3 visual confirm of Checking… → result on open.

## Reconciliation

**2026-09-26 tip:** Install self-update card auto-checks on open (parity with companion `_refreshProbe` in `initState`).

### Trigger

`_SelfUpdateCardState.initState` → `_runCheck()` (same cadence as Launcher/YNavi package probe). Screen is pushed via Navigator from Home, so re-open = new State = check again (“resume”).

### Soft fail

- `AppSelfUpdate.check` catches HTTP/parse errors → `AppUpdateCheckFailed`.
- **15s** network timeout (`kAppSelfUpdateTimeout`) so offline/GH hang does not block forever.
- Re-check soft path: if a prior **good** result exists and the new probe fails, keep last known status/action and append the error line (existing EN/RU `updateStatusFailed`).
- Manual **Check for updates** remains when no Update/Reinstall asset is shown.

### 0103

Update / Reinstall wording and companion probe behaviour unchanged.

### Changes

1. `appUpdateCheckerProvider` + injectable `AppUpdateChecker` (tests stub; prod → `AppSelfUpdate().check()`).
2. `_SelfUpdateCard` takes checker; auto `_runCheck` on `initState`.
3. Harness defaults to `AppUpdateNonePublished` so widget tests never hit GitHub.
4. Units: auto-check without tap, soft fail + last known, offline error, hang→timeout.
5. **No Live bump** — stays **1.1.0+23**.

### Verification

`flutter test` — `install_screen_test` + `app_self_update_test`. `dart analyze` clean on touched Dart.

**Divergence:** None from scope.


## ACCEPT (PDM 2026-09-26)

Tip `77a8b76` (1.1.0+23; Live not bumped). QA T2 dens320 PASS (`tmp/qa/0115-cut-77a8b76/`); four-point PASS (soft); units 31/31. Install open auto `_runCheck()` in `initState` — Checking…→latest/Reinstall without Check tap; manual Check kept; soft fail/15s timeout/last-known+error. 0103 Update/Reinstall wording untouched. Soft: car T3 visual Checking…→result on open. Live still **1.1.0+23**.
