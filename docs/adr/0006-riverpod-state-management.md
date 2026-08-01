# 0006 — Riverpod for state management and per-tier service injection

ADR 0003 makes each isolate derive its own view-state from service event streams, and ADR 0002 makes per-tier service swapping (real native ↔ Dart fake) the single most-cited requirement. We need one library that handles three things well: (a) clean per-tier service injection, (b) stream → derived-state, (c) inspectable/deterministic state for the agentic Feedback Loop (ADR 0004). Candidates: Riverpod, BLoC, Signals, flutter_hooks.

**Decision:** Riverpod is the state-management + dependency-injection layer.

- **Per-tier injection is native to it.** Each service (CarSignals, ConfigStore, MinimapHost, HudHost) is exposed as a provider; `ProviderScope` `override`s inject Dart fakes on T1 and real adapters on Android with **zero change to the Dart brain** — this is exactly ADR 0002's requirement, expressed in one mechanism.
- **Events → state with little ceremony.** `StreamProvider`/`AsyncNotifier` map a service's event stream to derived view-state; widgets `watch` it.
- **Loop-inspectable.** The Feedback Loop reads derived state through the `ext.zee.*` VM-service extensions.

> **Reconciliation (2026-07-31, recovery wave):** this bullet originally claimed `ProviderObserver` gives
> the loop "a uniform hook to dump derived state." No `ProviderObserver` exists anywhere in `lib/` and none
> was ever written. `ext.zee.readViewModel` reads `ConfigStore` and `CarSignals` **directly** — there is no
> `ProviderContainer` in `lib/debug/` — so the loop's view of state is assembled by hand, not observed.
> That is a real limitation, not just a doc error: hand-assembly is why `readViewModel` was still
> advertising a `plannedSlots` list containing the long-shipped minimap. A `ProviderObserver` remains a
> reasonable future improvement, but the ADR must not claim one that does not exist.

`flutter_hooks` is a complement, not a competitor — it handles widget-local state/lifecycle and pairs with Riverpod (`hooks_riverpod`); adopt it where it reduces `StatefulWidget` boilerplate.

**Considered options:**
- *BLoC* — the closest runner-up; its event→state model maps cleanly onto ADR 0003's relayed events and its explicit transitions are excellent for deterministic loop assertions (`bloc_test`). Rejected as the primary for more boilerplate and DI (`RepositoryProvider`) that is less aligned with per-tier overrides than Riverpod's `override`.
- *Signals* — leanest reactivity, but the youngest ecosystem; not a foundation bet for a multi-year, safety-relevant build.
- *Provider (bare)* — subsumed by Riverpod.

**Consequences:**
- Riverpod is **intra-isolate only.** It does **not** cross the isolate boundary — cross-isolate coordination is events/commands over the platform transport (ADR 0003). Each isolate owns its own `ProviderContainer`; the boundary is the relay, never a shared container.
- Both isolates run the same provider graph from the same `lib/`, so DHU and HUD derive consistently from the same events.
- Don't blend state managers; Riverpod is the single primary. `flutter_hooks` may coexist for widget-local concerns.
