---
status: done
labels: [foundation, finalization]
created: 2026-06-12
satisfies: foundation — MVP finalization for on-car (T3) testing
blocked-by: []
modules: [Installer, HudHost, MinimapHost, Feedback Loop]
tier: T2
---

# 0017 — Final sweep (MVP finalization for car testing)

## Block scope
Close out the MVP and make it genuinely ready for on-car (T3) testing: resolve the
one outstanding known-issue from Block 0014 (the installer double-start), reconcile
every doc that drifted from shipped reality, harden the two surfaces that touch a
real driver (HUD optics on the emissive projector; efficiency / no stray power draw),
bring the **Feedback Loop harness to "100%"** ergonomically (the new `drive-zee-app`
skill + a one-command launcher), and run a full T1/T2 verification sweep + builds.

This Block is the orchestrated finalization pass; the heavy lifting was delegated to
Sonnet agents and a verification swarm, with the orchestrator (Opus) integrating,
guarding the Principles, and runtime-confirming.

## Touches
- **Satisfies:** Foundation — implements ADR 0007 Definition-of-Done discipline (a Block is
  `done` only when runtime-confirmed, Principles honored, docs reconciled, trunk green).
- **Modules:** Installer (dedup guard), HudHost (HUD optics), MinimapHost (render-thread power),
  Feedback Loop (harness + skill).
- **ADRs:** 0007 (delivery discipline), 0004 (Feedback Loop), 0001 (HUD emissive rendering),
  0002 (one artifact).

## What this Block delivered

### 1. Installer dedup guard — closes Block 0014 §3 (runtime-confirmed on T2)
`InstallerController.startInstall` fired twice on a single Dart invoke (once from the
EventChannel `onListen`, once from the MethodChannel `start()`). A `@Volatile inFlightKey`
checked under `@Synchronized` makes the second trigger a NOOP; it is cleared at the
executor task's terminal state so re-install of the same asset still works and two
different assets still queue.

**T2 evidence** (emulator-5554, `beemdevelopment/Aegis v3.3 / aegis-v3.3.apk`, ~6 MB):
one real `startInstall:` (EventChannel onListen), one `already in flight — NOOP (dedup)`
(the `start()` trigger ~54 ms later), then `Download complete 6017348 bytes` →
`PackageInstaller session committed` → `progress: phase=done fraction=1.0`; Dart
`read-view-model --surface dhu` confirms `install.phase=done`.

Hardening applied in this Block: stale `startInstall` KDoc rewritten to describe the
actual guard; `inFlightKey` now cleared **before** the terminal `done`/`failed`
notification (closes a re-install re-tap race); defensive resets in `tearDown()` /
`onCancel` and on `RejectedExecutionException`.

### 2. HUD optics — production HUD is black except real marks (Principle 1/ADR 0001)
`hud_root.dart` rendered the GUIDANCE and MINIMAP placeholder `_SlotStub`s
unconditionally — emitted light on the windshield for unimplemented slots. They are now
gated to preview/debug context (the same flag as the Safe-Area border); the production
HUD draws only the real BLINKER + BATTERY marks. `readViewModel.activeSlots` reports only
the slots with real content (honesty for the Feedback Loop).

### 3. Minimap render thread — paused when hidden (Principle 2, efficiency)
The placeholder `MinimapView`'s ~60 fps render loop ran continuously even when the
minimap was hidden (`setMinimap(false)` only set the view `INVISIBLE`). It now pauses on
hide and resumes on show — no stray power draw. (Replaced by the real YNavi surface on T3;
this hardens the MVP placeholder that ships for first car testing.)

### 4. Feedback Loop harness at "100%" + the `drive-zee-app` skill
- `.agents/skills/drive-zee-app/` — the ergonomic operational skill: one-command launch
  per tier, the full 12-extension `ext.zee.*` contract, recipes, surface-resolution,
  hazards. Validated live on T1.
- `dev/zee_run.py` — launcher (`up`/`down`) that cleans stale forwards, starts `flutter run`,
  and waits until **both** DHU+HUD surfaces answer `whoami` before printing the ready VM URI.
- `dev/zee_drive.py` — T1 desktop VM-URI auto-discovery from the flutter-run log (was
  Android-logcat-only); canonical current-session URI file so driving a tier never reads a
  stale other-tier URI; `down` kills the process group; separate surface-readiness timeout.

### 5. Doc reconciliation (the board never lies — ADR 0007)
See the Reconciliation section.

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] Installer dedup guard runtime-confirmed on **T2** — logcat: one real `startInstall:` + one `already in flight — NOOP (dedup)` + `Download complete (6017348 bytes)` → `PackageInstaller session committed` → `phase=done`; `readViewModel.install.phase=done`. Re-confirmed after the hardening restructure.
- [x] HUD production surface confirmed black except real marks — artifact: `shots/final/t1-hud-production.png` (pure black + amber blinker + battery widget; **no GUIDANCE/MINIMAP ghosts**).
- [x] Minimap render thread confirmed paused on hide — logcat: `MinimapView: render loop RESUMED` (on enable) + `… PAUSED` (on disable).
- [x] Harness hardening validated — T1+T2 launched + driven via `zee_run.py up`; the canonical `/tmp/zee_vm_uri.txt` resolves automatically (no manual `export`); tier URI isolation closed.
- [x] `flutter analyze` clean; **191 tests** green (incl. new HUD-optics test); `build apk` (debug 47s + release 95s) + `build linux` (40s) ok.
- [x] Docs reconciled (below); BACKLOG/README reflect MVP-complete.

## Reconciliation
Doc drift found by the verification swarm and fixed in this Block:
- **README.md** Status — was "Foundation Wave 0 in progress / walking skeleton"; now "MVP complete". Running section updated to `dev/zee_run.py up`.
- **docs/issues/0011** — frontmatter `status: in-progress` → `done` (board already marked it done; the lone outlier).
- **docs/issues/BACKLOG.md** — added this Block (0017).
- **docs/feedback-loop-contract.md** — extension table expanded from 6 → the actual 12 `ext.zee.*` (added `inject, minimap, install, setLanguage, setUsbMode, bootState` + per-surface routing); fixed the stale `dhu-toggle` tap example (it lives on `HudSettingsScreen`, not mounted at startup — prefer `set-config` / a startup-screen key); `whoami` sample includes `hudEnabled`.
- **InstallerController.kt** — stale `startInstall` KDoc rewritten to describe the actual `inFlightKey` dedup.
- **Block 0014** — §3 known-issue (double-start) is now resolved; 0014 upgraded thin → strong.

## Deferred (tracked post-MVP follow-ups — honest, not silently shipped)
Non-blocking for first car testing; recorded so they aren't lost:
1. **HUD engine runtime teardown** — toggling `hudEnabled=false` mid-session leaves the second
   FlutterEngine + Presentation alive until process restart (it is correctly gated *at startup*).
   Add a command to dismiss/destroy the HUD engine on runtime disable (Principle 2).
2. **Minimap config → host wiring** — Block 0013's minimap config (preset/dimensions/theme) is
   persisted and relayed but does not yet drive `MinimapHost`; wire it when the real YNavi mod
   surface lands on T3.
3. **Dedup guard automated test** — the native double-start guard is covered only by live T2
   confirmation; add a Robolectric/androidTest for double-trigger idempotency.
4. **Real install_targets coordinates** — `install_targets.dart` ships TODO placeholder GitHub
   coords (the install *mechanism* is proven); the user supplies the real modded-Launcher /
   YNavi-mod release URLs, or gate the cards behind an availability check.

## Notes
Verification swarm verdict: `ship-with-fixes` — no hard blocker for first on-car testing;
all 16 prior Blocks artifact-backed; the #1 deliverable (installer dedup) runtime-confirmed
on T2; builds green. The fixes above were applied before close.
