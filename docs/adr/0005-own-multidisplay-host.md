# 0005 — Own the multi-display host; don't adopt a package

ADR 0001 needs a two-engine host that puts a transparent Flutter overlay *over* a native Minimap surface on the HUD Presentation. The obvious question is whether to adopt a pub.dev multi-display package instead of hand-rolling it. We surveyed the field — `presentation_displays` (109 likes but stale since 2024-03, 37 open issues, 120 forks), `flutter_multi_display`, `android_multi_display`, `sub_screen` (source unavailable — 404), plus forks/cousins — and read the Android source of every auditable one.

**Decision:** Own a thin native host (the ~200-line `_poc/multidisplay_poc` pattern). Do not take a dependency on a multi-display package.

**The decisive reason — packages invert Presentation ownership.** phase0's on-car-validated HUD (Path C, `CarAppHostService`) is a **native-owned single `Presentation`** whose view hierarchy layers the YNavi map `TextureView` (under a `ColorMatrixColorFilter` for HUD readability) *beneath* overlay layers (guidance, blinker). phase0 chose `TextureView` precisely so it composites *within* the view hierarchy. Flutter-first keeps that hierarchy native and slots the overlay layer in as a transparent `FlutterView` (PoC exp3). Every surveyed package instead **owns the `Presentation` as a Flutter-only surface** (`setContentView(flutterView)`, opaque), so it cannot host the native map+filter hierarchy. The closest, `android_multi_display`, hard-codes `TransparencyMode.opaque` and keeps the holder/engine private (source verified at `wirePresentation`), so preserving phase0's composition would require forking its internals — strictly worse than owning ~200 lines we understand.

*The Minimap is not the reason.* It is a **decoupled native sidecar** — a phase0 refactor with its own lifecycle, controlled by Flutter through a lean idempotent API (PoC exp3) — and is orthogonal to the engine count. What forces OWN is that the HUD `Presentation` must be **native-owned** to carry that sidecar and its filter; packages disallow exactly that.

**Supporting reasons:**
- *Memory.* ADR 0001 wants `FlutterEngineGroup` (shared VM/snapshot/GPU). Only our host and `flutter_multi_display` use it; `presentation_displays`/`android_multi_display` spawn bare `FlutterEngine`s, which would *worsen* the per-engine cost.
- *Event-relay model (ADR 0003).* `flutter_multi_display` mandates its own cross-engine `SharedStateManager` — precisely the competing state model ADR 0003 rejects. Owning the host keeps our own services in charge with raw channel access.
- *Host model.* `presentation_displays` is `ActivityAware` and uses the Activity as the Presentation context — fighting our foreground-service / thin-host boot (ADR 0002 single artifact).
- *Churn insulation is illusory.* The packages call the same `FlutterEngineGroup`/`FlutterView`/`DartExecutor` APIs we call, so a future Flutter break hits both — but with our own host we patch immediately instead of waiting on an unmaintained repo. `presentation_displays` (stale, 37 open issues) is the cautionary tale on a multi-year horizon.

**Consequences:**
- We maintain ~200 lines of Kotlin host code. The trade is ~50 lines of saved boilerplate vs. zero dependency risk on the rendering critical path of a long-lived, safety-relevant car app.
- Revisit only if a package later exposes the Presentation's view hierarchy (native under-layer) *and* leaves engine/state ownership to us.
- **New risk (carried to ADR 0004):** VM-service drivability of the secondary isolate is assumed from the standard embedding mechanism, not yet runtime-proven; confirm with a `getVM` isolate-count + `ext.zee.*` reachability check when the engine-spawn path is built.
