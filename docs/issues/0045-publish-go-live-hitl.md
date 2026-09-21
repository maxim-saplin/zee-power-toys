# 0045 — Publish go-live (HITL)

## Status
blocked-by: [0044]

## Goal
When all three repos are publishable-shape (0044 green), run a **human-in-the-loop** go-live. Agents prepare; **Maxim** accepts changes and signs off each step.

## Preconditions (0044)
- [ ] Prep branches green: GH Actions tested on GitHub
- [ ] Dual YNavi APKs built; T2 install both + zee-power proven
- [ ] Launcher built (emulator N/A)
- [ ] Install points at **Release** assets (not git LFS / committed APKs)
- [ ] Release **drafts** used for testing; disposable until go-live

## Migration rule
**Stop keeping builds in `.git`.** Binaries live on GitHub Releases only. During prep: draft releases for CI/Install testing; delete drafts after the exercise if Maxim wants a clean slate before real publish.

## Go-live steps (HITL — Maxim accepts each)

1. **Review** prep PRs / branches on all three repos (`zee-power-toys`, `ynavi-zee`, `zee_hud_2`)
2. **Merge** to main (Maxim commit/merge)
3. **Publish** real (non-draft) Releases with margined YNavi (default), OS7 no-margin, Launcher v8+, zee-power platform APK as applicable
4. **Point** Install targets at final Release URLs; bump if needed
5. **Verify** Install URLs HTTP 200 anonymous (repos/releases public as required)
6. **Sign-off** — Maxim go; agents do not push release without it

## DoD
- [ ] Maxim signed off go-live
- [ ] Main + Releases live
- [ ] Draft test releases cleaned up (if requested)
- [ ] README/Install honest vs live artifacts

## Maxim HARD (2026-09-20): zee_hud_2 OUT of publish scope
Launcher = `maxim-saplin/zeekr_apk_mod` only. Trio: zee-power-toys, ynavi-zee, zeekr_apk_mod.
