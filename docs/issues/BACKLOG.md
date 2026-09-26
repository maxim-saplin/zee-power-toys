# Issues — the backlog & board

- [ ] **0112** Drive-mode colors ECO blue / Comfort green / Sport red — tip `2bf2a30` — `0112-drive-mode-colors-eco-blue-comfort-green-sport-red.md`
- [ ] **0111** Spike: instant drive/regen power magnitude (cluster bar) — `0111-instant-power-magnitude-spike.md`
- [x] **0110** Drive-mode persistent BR corner dot (settings toggle) — ACCEPT `36f2384` — `0110-drive-mode-corner-dot.md`
- [x] **0109** Drive-mode toast higher + blue/green/red — ACCEPT `67eccc5` — `0109-drive-mode-toast-higher-colors.md`
- [x] **0108** Own-range honesty window (~50 km, heavier recent 10/3 km) — ACCEPT `11ae3cd` — `0108-own-range-honesty-window.md`
- [x] **0107** Own-range HUD polish (always-visible pending + typography/layout) — ACCEPT `e1c3419` — `0107-own-range-hud-polish.md`
- [x] **0106** Overlay size slider scales window + CRT content — ACCEPT `488d7ec` — `0106-overlay-size-noop.md`
- [x] **0105** Own estimated range beside battery % (toggle + plain how) — ACCEPT `97784bb` — `0105-hud-own-range-estimate.md`
- [x] **0104** HUD drive-mode change toast 5 s fade — ACCEPT `bc48d13` — `0104-hud-drive-mode-toast.md`
- [ ] **0097** YNavi mod hardening matrix (v27 + v30 on T2) — see `0097-ynavi-mod-hardening-matrix.md`
- [x] **0103** Install Update vs Reinstall + YNavi/Launcher version align — ACCEPT `bb45870` (`0103-install-update-vs-reinstall.md`)
- [x] **0102** Other traffic cams false speedcam alerts — ACCEPT `62720d0` (`0102-other-traffic-cams-false-alert.md`)

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
| [0023](0023-drivability-dhu-ux-localization.md) | **Drivability fix + DHU UX + localization** — `tapByKey` callback fix + dhu-only inject + HUD-settings split + USB hub tile + minimap presets + `setLanguage` unsupported off-car + EN/RU slot labels (QA3-1/2/3, QA2-1/2/4/5/6/7/8) | ADR 0003/0004 | **done** |
| [0024](0024-repo-hygiene-docs-scale-test.md) | **Repo hygiene + docs + scale test** — untrack dead-weight binaries + gitignore, `dhuSmartScale` test (+10 → 209), `debugPrint`, README/CONTEXT/contract/SKILL reconcile, tracked-deferral list (QA5-1/2/3/9/14, QA3-4/6/7) | ADR 0007 | **done** |
| [0025](0025-minimap-safe-area-confinement.md) | **Minimap Safe-Area confinement** — phase0 square viewport geometry + empirical Safe Area (T2); `filterWrapper` sized (not MinimapView); `setBounds`-before-`enable` ordering; dp-constant model + 19 geometry tests | ADR 0001/0005 | **done** |

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
| [0026](0026-hud-preview-vs-live-simulate-split.md) | Split Config Preview (always-visible demo, no signal needed) from Developer Simulate (in-app live CarSignal injection); retire dead `hudBoxOn` | HUD · preview | **done** |


### T3 boot remediations  (2026-09-19 — Maxim)

Port remaining phase0/`zee_hud_2` boot tooling onto zee-power-toys. Partial auto-start already exists ([0010](0010-boot-fgs-autolaunch.md): BootReceiver → FGS + optional USB).

| ID | Item | Status | Notes |
|----|------|--------|-------|
| — | **Boot: cluster locale → English** — AdaptAPI `0x20318a00=1` on `BOOT_COMPLETED` (phase0 `BootActions.pushClusterLocaleEnglish`) | **done** | Wired via `BootRemediation.runOnBootAsync` |
| — | **Boot: YNavi Doze whitelist** — add `ru.yandex.yandexnavi` to power-save whitelist | **done** | Same BootRemediation path |
| — | **Manual silent YNavi restart** — `forceStopPackage` (phase0 `RESTART_YNAVI_SILENT`); Language settings + `zee/boot.restartYNavi` | **done** | No automatic network-recovery loop (phase0 retired that) |
| — | **Automatic YNavi/network remediation on flaky data** | **wontfix / upstream** | Phase0 retired automatic restart; traffic fix lives in YNavi mod |

### Publish & release  (customer backlog 2026-09-19 — Maxim)

Mechanism for Install is **done** ([0014](0014-install-from-github.md) / [0020](0020-leftovers-scale-install-minimap.md)); the **published artifacts + links + CI** are not. Track here until promoted to numbered Blocks.

| ID | Item | Status | Notes vs today |
|----|------|--------|----------------|
| — | **Publish Launcher APKs** — inventory correct XCLauncher versions for Zee APK mode; publish signed builds to GitHub (LFS) so Install → Launcher is real | **backlog** | `kLauncherAsset` → `maxim-saplin/zee_hud_2` `main` …/`XCLauncher3-670-proxy-signed-v8.apk`. Download URL fixed; **never runtime-confirmed** on T2/T3. Need: canonical version list + publish process + bump `install_targets.dart`. |
| — | **Publish YNavi mod APKs** — merge `hud` → `main` if still needed; publish a **post-P1** bind-capable APK (v12+) to LFS | **backlog** | `kYnaviAsset` → `maxim-saplin/ynavi-zee` `hud`/`modded_apks/zeekr_signed_v11.apk` is **KNOWN BROKEN** (pre-P1 host allowlist; bind fails). Working build lives in gitignored `builds/`. Must republish then bump path. |
| — | **Proper GH links in Install UI** — show repo/branch/path (or release URL) on each Install card; openable | **backlog** | `InstallScreen` today: name + desc + Install button only — no visible GitHub coordinates. |
| — | **YNavi build variant without left letterbox** — ZeekrOS 7+ layout; `ZEEAPP_LETTERBOX_LEFT_DIP` (480dp) no longer wanted; ship a separate APK (or preset) without left padding | **backlog** | Upstream `ynavi-zee` (`features/1.mapactivity_letterbox_padding`, `dimens.xml` zeeapp_letterbox_left). Dual publish: legacy padded + OS7+ unpadded. Wire second Install target or selector. |
| — | **GH Actions for zee-power-toys + release process** — CI (analyze/test/apk) and tagged release artifacts | **backlog** | No `.github/workflows` in this repo today. |
| — | **README as product landing** — intro, quick start, screenshots, guide, links to sibling repos (ynavi-zee / launcher / phase0), architecture at the bottom | **done** (`1.0.0+5`) | Front face + quick start + companions; screenshot placeholders until Maxim icons; arch last. |

Related deferred: installer Robolectric guard (below); YNavi zoom still upstream (`ZEEAPP_MAP_SCALE_PERCENT`).

### Speedcam follow-ups (0046–0050)

| [0050](0050-speedcam-car-location.md) | YNavi/car GPS → Speedcam pose + harvest center (no silent Minsk) | in-progress |

| [0046](0046-speedcam-dhu-map-preview.md) | DHU map preview of cached cams | in-progress (folded w/ 0047) |
| [0047](0047-speedcam-harvest-300km.md) | Harvest ~300 km of host pose; merge no-purge; no BY UI | in-progress |

### Quality + publish

| [0051](0051-battery-free-placement.md) | Battery HUD free placement (left / right / right-top + fine adjust) | **done** |
| [0054](0054-settings-survive-reinstall.md) | Settings survive reinstall via `adb install -r` (no uninstall / no sdcard mirror) | **done** |
| [0056](0056-battery-looks-pdm.md) | Battery looks — PDM names + squarish bold outline | **done** |
| [0057](0057-minimap-only-while-guidance.md) | Show minimap only while YNavi guidance active (default off) | **done** |
| [0055](0055-ynavi-minimap-info-overlay.md) | Street/ETA via native GuidanceOverlayView (Zee HUD 2 updateTrip) | in-progress (FAIL redirect) |
| [0058](0058-hud-approach-cam-blip.md) | HUD approach cam blip — relative bearing fold | **done** |
| [0059](0059-speedcam-alert-loudness.md) | Alert loudness — NAV stream + real slider gain | **done** |
| [0061](0061-guidance-overlay-scale-slider.md) | GuidanceOverlayView overlay scale slider (Zee HUD 2 0.25–1.0) | **done** |
| [0060](0060-speedcam-hud-sound-modes.md) | Speedcam HUD + sound modes (Any / Dangerous / Off) | **done** |
| [0062](0062-battery-pct-inside-dual-color.md) | Battery + % inside pack — dual-color clip at fill (FAIL: empty white) | **done** |
| [0063](0063-battery-outline-pct-height.md) | Battery polish — thinner outline + full-height % (keep 0062 clip) | **done** |
| [0064](0064-speedcam-blip-colors.md) | Speedcam HUD blip colors — danger white / others greenish | **done** |
| [0066](0066-hud-charging-indicator.md) | HUD charging indicator — register+seed/poll CHARGE_STATE (live bolt/kW) | **done** (code; T3 QA pending) |

| [0043](0043-quality-sweep-pre-publish.md) | Quality sweep pre-publish (deps, T1/T2 matrix, debt, coverage, docs) | **done** @ 1bed77b (ACCEPTed) |
| [0044](0044-publish-prep-three-repos.md) | Publish prep 3 repos — review-ready, await Maxim go | in-progress (zee-dev) |

### Speedcam (0029–0042) — **done** on T1/T2

Product cut shipped through Alien fidelity + Demo; tip of record `956d6b8`. Quality sweep [0043](0043-quality-sweep-pre-publish.md). Residual taste polish is not a numbered block unless Maxim reopens.


### Out of scope (post-MVP, architecture-ready)

See also: [phase0 / YNavi A/B testing protocol](../knowledge/phase0-ynavi-ab-testing.md) — how to compare phase0 reference vs our app on one emulator or on-car, without conflict.
- ~~**Speedcam** (+ Alien mode)~~ → **shipped** as [0029](0029-speedcam-osm-epic.md)–[0042](0042-speedcam-alien-fidelity.md) (`SpeedcamService` + OSM packs + Default/Alien looks).

### Deferred hardening (tracked, low-priority — surfaced by the QA sweep)
Non-blocking polish noted so it is never invisible. None gate on-car (T3) testing.
- ~~**Minimap surface confinement**~~ → **resolved as [Block 0025](0025-minimap-safe-area-confinement.md)** — `filterWrapper` sized to viewport rect; phase0 dp-constant geometry; `setBounds`-before-`enable` ordering. Proof: `shots/redo/t2-hud-minimap-confined.png`.
- **Installer dedup automated test** (QA5-9 / 0017 §3) — Robolectric double-trigger guard for the native installer; logic is in place, the regression test is not.
- ~~**Per-tier VM-URI files**~~ (QA3-5) → **resolved 2026-08-01** — `/tmp/zee_vm_uri_{tier}.txt` plus a `getVersion` liveness probe that unlinks a stale file and falls through instead of hanging on the RPC timeout.

#### Minimap zoom & label scale — **upstream, not fixable here** (2026-08-01)
The map renders far too close: at the 210x210 viewport a single street label plus its Cyrillic
second line occupies roughly a third of the frame, and labels clip at the viewport edge.

Measured conclusions, so this is not re-litigated:
- **Neither runtime lever moves the zoom.** `bufScale` changes only render resolution/anti-aliasing;
  `dpiScale` has no effect anywhere from 0.8x to 4x, including through a full `stop()`/`start()` cold
  re-bind that guarantees a fresh `onSurfaceAvailable`. The CarApp surfaces we bind to
  (`AppManager`/`NavigationManager`) expose no camera or zoom control.
- The one concrete lever is **`ZEEAPP_MAP_SCALE_PERCENT` (=130), a compile-time flag in the separate
  `ynavi-zee` mod repo.** Fixing the zoom means rebuilding and republishing that APK.
- **Do not "fix" the label clipping by over-rendering into a larger buffer and centre-cropping.**
  Clipping at a viewport edge is normal for any cropped map view. Centre-cropping shows *less*
  geographic area at the same pixel scale while labels stay the same size — it makes the real problem
  (over-zoom) worse in exchange for removing a normal artifact. Rejected deliberately, not overlooked.
- **FGS auto-start in dev** (QA4-7) — the foreground service starts only via `BootReceiver`, so `bootState.fgsRunning` is always `false` under `flutter run`; a `TEST_BOOT` hook in `zee_run.py up` would exercise it.
- **Behaviour-boundary test cleanups** (QA5-12/13) — `native_car_signals_test` asserts `snapshot.*` internals and `hud_root_test` pins `AspectRatio` type; prefer the event stream / rendered bounds.
- **Conventions-doc dep snapshot** (QA5-11) — `docs/knowledge/flutter-conventions-riverpod-testing.md` lists illustrative deps (`go_router`, `logging`, `mockito`, `build_runner`) the app deliberately does not use.
- **System-language OTA write — T3-only verification** (Block 0015 follow-up) — `SystemConfigController.setSystemLanguage` now routes through the AdaptAPI/OTA path (`IOtaSession.setSystemHMILanguage`, with an `AdaptInternalManager` fallback) instead of the previous in-process resource-configuration mutation that reported success without actually changing anything persistent or system-wide. T1/T2 correctly report `unsupported-on-device` (no AdaptAPI) via a dedicated `systemSupported()` capability probe, replacing the old ungrantable-permission gate. **Whether the OTA call actually changes the car's system language has not been runtime-verified anywhere but T3** — it may still fail there this wave without platform signing (no `sharedUserId` in the manifest; release signs with the debug key). Do not accrete further fallback mechanisms to paper over this gap; confirm on-car instead.
- [ ] 0067 HUD battery cluster grow while charging (3 lines)
- [ ] 0067b battery sizeScale grows slot (monotonic)
- [x] 0068 charge UI snapshot providers + CI keystore
