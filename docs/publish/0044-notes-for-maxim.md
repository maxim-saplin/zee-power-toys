# 0044 — Publish prep notes for Maxim (review, no green)

**Status:** drafts on branch `0044-publish-prep` in `zee-power-toys`.  
**Rule:** no push / no GitHub Release / no CI enable until your explicit go.

## 1. zee-power-toys

| Item | Draft | Needs your go |
|------|-------|----------------|
| Platform-signed release | `android/app/build.gradle.kts` already prefers AOSP debug key when `-PuseAospDebugKey=true` (car). Documented in README Install section. | Confirm keystore path / release recipe |
| Install targets | Still point at current LFS URLs; YNavi **known broken** (v11 pre-P1) called out in-app notes + here | After ynavi `v12` lands, bump `lib/services/install_targets.dart` |
| README landing | Consumer-facing Install / Get APKs section added | Edit tone / links |
| CI | `.github/workflows/build-android.yml` — `workflow_dispatch` only, **disabled** `if: false` until go | Flip `if` / enable on tag |

Build recipe (car):

```bash
flutter build apk --release -PuseAospDebugKey=true
# APK: build/app/outputs/flutter-apk/app-release.apk
```

## 2. ynavi-zee (`hud` branch)

| Item | Reality | Pending action (you / agent after go) |
|------|---------|----------------------------------------|
| Published LFS | `modded_apks/zeekr_signed_v11.apk` — **pre-P1**, cannot bind (`Unrecognized host`) | Replace with post-P1 build |
| Working local | `builds/zeekr_signed.apk` (~202 MB, gitignored) from `hud` @ `879c70b3c` | Copy → `modded_apks/zeekr_signed_v12.apk`, `git lfs track`, commit on `hud` |
| OS7+ unpadded | Not in tree as a named artifact yet | Confirm whether `zeekr_no_keepalive_signed.apk` or a separate unpadded build is the OS7+ variant; publish under clear name |
| Install bump | After v12 on LFS | Point `kYnaviAsset.path` to `modded_apks/zeekr_signed_v12.apk` |

## 3. launcher — zee_hud_2 (`main`)

| Item | Reality | Pending |
|------|---------|---------|
| Install path | `XCLauncher3-670-proxy-signed-v8.apk` on `main` (LFS) — URL resolves | E2E install never T2/T3 confirmed |
| Older v2–v7 | Present; leave as history | None |
| Publish | Already on `main`; no new APK required for URL honesty | Optional: tag / Release notes when go |

## Suggested review order

1. Read this file + README Install section.
2. Decide: push `0044-publish-prep` → `main` when ready.
3. Go on ynavi LFS `v12` (+ OS7+ name).
4. Bump `install_targets.dart` + enable CI workflow.
5. Only then: car release binary / Install green.

## Out of scope until go

- GitHub Releases upload
- Enabling the workflow on `push`/`tag`
- Claiming Install is production-ready while YNavi v11 is the target

## Sibling NOTES (local commits, not pushed)

| Repo | Branch | Local tip | File |
|------|--------|-----------|------|
| ynavi-zee | `hud` | `8ffe0aed6` | `NOTES-for-Maxim-0044.md` |
| zee_hud_2 | `main` | `72651e1c5f` | `NOTES-for-Maxim-0044.md` |
| zee-power-toys | `0044-publish-prep` | this branch | `docs/publish/0044-notes-for-maxim.md` |
