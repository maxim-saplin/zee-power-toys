# 0001 — Flutter-first UI with a thin native host

We want a rich, fast-iterating UI (hot reload, a single state-management stack) across both the DHU touchscreen and the windshield HUD, while reusing phase0's on-car-validated native HUD plumbing. Three shapes were on the table: all-native (phase0's approach), Flutter for the touchscreen only with native HUD overlays, and Flutter for *all* designed UI on both surfaces.

**Decision:** Flutter renders 100% of the UI we design — on both the DHU touchscreen and the HUD. Native Kotlin is a thin platform host: it creates the secondary-display `Presentation`, attaches a `FlutterView` to it ("places Flutter pixels on the HUD"), reads car signals via AdaptAPI, hosts YNavi, and does system glue (boot, foreground service, installs). The two Flutter surfaces run as two engines via `FlutterEngineGroup` — not one engine with two views (see Validation).

**The one exception — the Minimap.** YNavi draws map tiles into a `Surface` we hand it; those pixels are foreign to both stacks. The Minimap stays a native `TextureView` composited *under* a transparent Flutter overlay, and the green-yellow HUD readability filter is applied natively on that TextureView. Everything else on the HUD is Flutter. Piping the map into Flutter as an external texture was considered and deferred — too risky to adopt before the base path works.

**Validation (PoC `_poc/multidisplay_poc`, Flutter 3.44.1, Android x86_64 emulator + overlay display).** The two-engine choice is empirically forced, not stylistic:
- *Single-engine multi-view FAILS.* Attaching a 2nd `FlutterView` to the same `FlutterEngine` returns `isAttached=true` (a false positive) but the secondary display renders **blank** — one classic engine drives exactly one rendering surface. Flutter 3.44's Android embedding has no working multi-view API for a secondary `Presentation`.
- *Two engines via `FlutterEngineGroup` WORK.* Both displays render; the two isolates are independent (a shared `tick` counter diverged 150 vs 148), which is precisely why ADR 0003 keeps canonical state in native.
- *Transparent Flutter over a native surface WORKS.* A `FlutterTextureView` with `isOpaque=false` composited Flutter overlays over a native `TextureView` Minimap stand-in on the secondary display — validating the Minimap exception above.
- *The lean Dart→native Minimap control API WORKS and is idempotent.* `setMinimap(false)` hid the native surface; a repeated `setMinimap(true)` logged `NOOP (already shown)`.

**Consequences:**
- The HUD preview stops being a separate mock — it is the same Flutter widget subtree rendered in a window/region, so it cannot drift from the real HUD.
- A transparent Flutter surface over the map requires the TextureView-backed renderer (`FlutterTextureView`) — PoC-validated on the emulator; still confirm on-car.
- Two engines cost memory (~80 MB delta in the debug PoC, ~268 MB total; lower in release as `FlutterEngineGroup` shares VM/snapshot/GPU context). The HUD engine runs only while the HUD is active.
- If the 2nd-engine cost ever outweighs the benefit, the fallback lever is native HUD overlays (Flutter only on the DHU) — at the cost of reintroducing preview/real drift this ADR exists to kill.
- The two-engine host is hand-rolled, not a pub.dev package — see ADR 0005 (every surveyed package owns its Presentation Flutter-only and cannot host the native Minimap under-layer).
