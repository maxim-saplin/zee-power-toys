# 0044 — Publish prep (three repos), review-ready, no green

## Status
in-progress — drafts on branch `0044-publish-prep` (no push until Maxim go)


## Goal
Stage **review-ready** publish changesets on main (or review branches Maxim prefers) for:
1. `zee-power-toys` — platform-signed release story, Install targets/links, README landing, GH Actions
2. `ynavi-zee` — post-P1 APK publish path + OS7+ unpadded variant
3. launcher (`zee_hud_2` / XCLauncher) — correct APKs published / pointed

**Maxim** reviews tomorrow; **no commit/push/publish** until his explicit go.

## DoD
- [x] Each repo has a clear pending changeset + short notes for Maxim — see `docs/publish/0044-notes-for-maxim.md` (ynavi/launcher actions listed; APK LFS commits await go)
- [x] Install points at real artifacts (or honest “pending upload” with paths) — YNavi v11 broken called out; v12 path documented
- [x] README landing draft in zee-power-toys
- [x] CI workflow draft (disabled `if: false` until go)
- [ ] Maxim explicit go → push branch / LFS v12 / enable CI
