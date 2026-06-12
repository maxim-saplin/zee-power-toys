# Issues — the backlog & board

The single ledger of work. Each row is a **Block** (ADR 0007): a thin vertical slice of delivered value, **runtime-confirmed**. A Block *points at* its two stable references — it does not restate them:
- the **what** → [REQUIREMENTS.md](../../REQUIREMENTS.md)
- the load-bearing **how** → [docs/adr/](../adr/)

Most rows are one-line **stubs**; a stub becomes a full `NNNN-slug.md` (copy [TEMPLATE.md](./TEMPLATE.md)) only when its turn comes — **just-in-time, not waterfall**. The "what" detail for a slice is written into its Block then, learning from the Block before it.

See also: [PRINCIPLES.md](../PRINCIPLES.md) (Definition of Done) · [ADR 0007](../adr/0007-block-by-block-agentic-delivery.md) (delivery model).

## Discipline

1. **One Block in-progress at a time.** Foundation first; the **walking skeleton (0001) before anything else**.
2. **Lifecycle:** `backlog` → `ready-for-agent` → `in-progress` → `done` (or `blocked` + one-line why + `blocked-by`).
3. **`ready-for-agent`** is the unattended-pickup signal — an agent may claim it without asking.
4. **`done` means runtime-confirmed** — the Definition of Done in [PRINCIPLES.md](../PRINCIPLES.md) is met, with an artifact. Not "code written."
5. **Elaborate just-in-time.** Promote a stub to a file (assign the next `NNNN`, copy [TEMPLATE.md](./TEMPLATE.md)) only when it's next to be built.
6. **Reconcile in the same Block.** If reality contradicts a doc (ADR / CONTEXT / REQUIREMENTS / Issue), fix it before closing.
7. **The board never lies** — every status change lands in the same commit as the work.

## How an agent runs a Block — the rollout loop

The entry point for an unattended agentic rollout. Repeat until the backlog is dry:

1. **Claim.** Take the lowest-ID `ready-for-agent` Block with an empty `blocked-by`. Set `status: in-progress` (+ owner). Only one Block in-progress at a time.
2. **Orient.** Read the Block, its referenced ADRs, the `satisfies` requirement in [REQUIREMENTS.md](../../REQUIREMENTS.md), the glossary in [CONTEXT.md](../../CONTEXT.md) (use its terms), and [PRINCIPLES.md](../PRINCIPLES.md) (the gate).
3. **Build the slice.** Implement *just this Block*, lifting from the grounding PoCs it cites. Match surrounding code; test at the behaviour boundary.
4. **Runtime-confirm.** Drive + read the change through the Feedback Loop on the Block's Tier (the `verify` skill / the client from Block 0002). Capture the artifact named in the DoD.
5. **Reconcile.** If reality contradicted any doc, fix it (ADR / CONTEXT / REQUIREMENTS / Issue) and record it in the Block's **Reconciliation** section.
6. **Close.** Tick the DoD, set `status: done`, update this board, commit (board + code in one commit). Then elaborate the next stub into a file and flip it `ready-for-agent`.

If a Block won't fit one loop, **split it at its marked seam before starting** (record the split). If blocked, set `blocked` + a one-line why + `blocked-by`, and move to the next unblocked Block.

## Board

IDs are assigned on elaboration (`—` = still a stub).

### Wave 0 — Foundation  (`foundation` label; implements ADRs; no requirement parent)
Builds the spine the whole app hangs off. Confirmed on T1 first, then re-confirmed on T2 when the native edge is involved.

| ID | Block | Touches | Status |
|----|-------|---------|--------|
| [0001](0001-walking-skeleton.md) | **Walking skeleton** — T1 end-to-end loop: gesture → ConfigStore write → event → both isolates re-derive → pixel change, driven + read via the Feedback Loop | ADR 0001/0003/0004/0006 | **done** |
| — | Android two-engine host: `FlutterEngineGroup` + secondary `Presentation` + `FlutterView` on Display-2 | ADR 0001/0005 | _moved to [0004](0004-android-two-engine-host.md)_ → **done** |
| — | Services/ports skeleton (CarSignals, ConfigStore, MinimapHost, HudHost, Installer, SystemConfig) + Riverpod injection | ADR 0003/0006 | _moved to [0003](0003-services-ports-skeleton.md)_ → **done** |
| [0002](0002-feedback-loop-client.md) | Feedback Loop client: dual-channel (VM-service `ext.zee.*` + native ADB/broadcast dump), tier-agnostic | ADR 0004 | **done** |
| — | Environment-selected adapters: single APK, AdaptAPI-or-simulator auto-select, ADB override + native CarSignals + broadcast feedback channel | ADR 0002/0004 | _moved to [0005](0005-environment-selected-carsignals.md)_ → **done** |
| — | Minimap under-layer: native `TextureView` + green-yellow `ColorMatrix` filter + idempotent `setMinimap` command | ADR 0001/0005 | _moved to [0009](0009-minimap-under-layer.md)_ → **done** |
| — | Boot shim + ConfigStore plain native-readable format + foreground service + auto-launch | ADR 0003/0002 | _moved to [0010](0010-boot-fgs-autolaunch.md)_ → **done** |
| — | Safe Area: hand-calibrated rectangle applied to the HUD surface, with preview parity | ADR 0001 | _delivered with the HUD-preview feature Block_ |
| [0017](0017-final-sweep.md) | **Final sweep** — installer dedup reconciliation (0014 §3), docs/contract reconciliation, HUD-optics + efficiency hardening, MVP finalization for on-car testing | ADR 0007 | **done** |
| [0018](0018-premium-ui-ynavi-host.md) | **Premium DHU UI + real YNavi CarApp host** — dark M3 theme + 160-dpi scale fix + small-circle blinker; YNavi `NavigationCarAppService` bind (handshake/surface/location confirmed; map render → 0019) | ADR 0001/0005/0007 | **done** |
| [0019](0019-ynavi-map-render.md) | **YNavi cluster map render** — draw the real YNavi map onto the HUD surface (phase0 recipe: `pm clear` + perms, P9 paywall bypass, surface-race + template-probe fixes) | ADR 0001/0005 | **done** *(map rendered; readability fixed in 0021)* |
| [0020](0020-leftovers-scale-install-minimap.md) | **Leftovers** — DHU low-DPI UI scale-up (3.0× at 2560×1600@160dpi) + MinimapConfig→MinimapHost preset wiring + real LFS install coordinates + `nav-hud` doc reconcile | ADR 0001/0004/0007 | **done** |
| [0021](0021-hud-minimap-readability-phase0-filter.md) | **HUD minimap readability** — phase0 `filterWrapper` pattern + parametric `createHudFilterPaint` + night mode + 2× zoom-out; fixes the yellow-wash from 0019 | ADR 0001/0005 | **done** |
| [0022](0022-hud-optics-lifecycle-hardening.md) | **HUD optics + lifecycle hardening** — black bg + real-display minimap bounds + battery Safe-Area inset + HUD-engine runtime teardown + native thread/alloc lifecycle (QA1-1/2/4/7, QA4-1–6) | ADR 0001/0003 | **done** |

### Wave 1+ — Feature areas  (satisfies → [REQUIREMENTS.md](../../REQUIREMENTS.md))
One stub per capability; each fans into its own Blocks when its turn comes.

| ID | Area | Satisfies | Status |
|----|------|-----------|--------|
| [0013](0013-minimap-config.md) | Minimap configuration — YNavi enable/disable, presets, basic/advanced, dark-light auto | HUD · Minimap | **done** |
| [0007](0007-blinker-customization.md) | Blinker customization — shape (dots / arrows / smiley), size, position | HUD · Blinker | **done** |
| [0008](0008-battery-charging.md) | Battery & temp widget — Steam-Deck-style looks | HUD · utility info | **done** |
| — | Charging stats — show while charging, hide otherwise | HUD · utility info | _delivered in [0008](0008-battery-charging.md)_ → **done** |
| [0006](0006-hud-layout-safe-area-preview.md) | HUD preview + Safe-Area simulation in the main UI (grey BG) — HUD layout scaffold | HUD · preview | **done** |
| [0014](0014-install-from-github.md) | Install modded Launcher + YNavi mod from GitHub | App-shell · install | **done** |
| [0015](0015-system-cluster-language.md) | System + Cluster language change | App-shell · language | **done** |
| [0012](0012-diagnostics-dashboard.md) | Diagnostics dashboard — clean up the phase0 AP browser | App-shell · dashboard | **done** |
| — | Localization EN / RU — picks system lang, choosable in UI | Cross-cutting | _moved to [0011](0011-localization-nav-shell.md)_ → **done** (+ DHU nav shell) |
| [0016](0016-usb-adb-toggle.md) | zSupport-1.3.5 decompile → USB host/peripheral ADB toggle (spike) | Research | **done** |

### Out of scope (post-MVP, architecture-ready)

See also: [phase0 / YNavi A/B testing protocol](../knowledge/phase0-ynavi-ab-testing.md) — how to compare phase0 reference vs our app on one emulator or on-car, without conflict.
- **Speedcam** (+ Alien mode) — slots in as a future `SpeedcamService` + a location signal; no design effort now. ADR 0003's service-port model makes it additive (events out: nearest cam, danger level; commands in: lane toggles), with radar / alien visuals being more Flutter HUD content (ADR 0001).
