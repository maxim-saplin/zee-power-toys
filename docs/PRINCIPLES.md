# Principles & Definition of Done

The intent behind Zee Power Toys is **software that doesn't suck**: powerful, customizable, and clean — never bloated, never wasteful, always drivable. These principles are not aspirational prose; they are the **standing gate every Block passes** before it can be marked `done` (ADR 0007). Every Issue inherits this page.

## Principles

1. **Simplicity beats configurability when they conflict.** Customization is the product; bloat is the bug. The requirement is explicit: *"fighting for simplicity and cleanliness — the app must not turn into a bloated experience."* Every new option must earn its place, and **defaults must be excellent** so most users never need to open advanced settings.

2. **Efficiency by default.** No power-hungry code, no unnecessary wake locks. Engines and listeners run only while needed — the HUD engine runs only while the HUD is active (ADR 0001). This is a car that sleeps; respect its battery.

3. **Always runtime-drivable.** The app stays as inspectable and CLI-drivable as phase0, on every Tier. Agentic loops are first-class users, not an afterthought — if a feature can't be driven and read back through the Feedback Loop (ADR 0004), it isn't finished.

4. **One artifact, no drift.** A single APK across emulator and car; environment-selected adapters, never build flavors (ADR 0002).

5. **Direct APIs only.** Talk to AdaptAPI directly; no reliance on a Launcher proxy.

6. **No dead weight.** Reuse phase0's validated plumbing, but carry over nothing unnecessary. Tests cover external behaviour; docs ship with the code.

## Definition of Done

A Block is `done` only when **all** of the following hold:

- [ ] **Runtime-confirmed** on the appropriate Tier via the Feedback Loop, with an attached artifact (screenshot / state dump / log). Code that only compiles or only passes unit tests is **not** done.
- [ ] **Honors the Principles above** — reviewed for simplicity (no needless options), efficiency (no stray wake locks / always-on engines), and drivability.
- [ ] **Tested at the behaviour boundary** — external behaviour, not implementation detail (see the `tdd` skill).
- [ ] **Docs reconciled** — any divergence from an ADR / CONTEXT entry / REQUIREMENTS / Issue discovered while building is fixed *in this same Block*.
- [ ] **Trunk stays green** — no regression to any previously-delivered Block.
