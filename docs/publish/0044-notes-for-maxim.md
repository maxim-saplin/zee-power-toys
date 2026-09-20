**HARD:** `zee_hud_2` is NOT in publishing scope. Launcher = `zeekr_apk_mod` only.

# 0044 — Publish prep notes for Maxim (review, no green)

**Status:** drafts on branch `0044-publish-prep` in `zee-power-toys`.  
**Rule:** no push / no GitHub Release / no CI enable until your explicit go.

### QA FAIL (0044 T1)

Launcher anonymous LFS URL → **404** because `zeekr_apk_mod` is private. YNavi (`ynavi-zee` public) LFS → 200 (bind still pre-P1 broken). Install cannot ship green until Launcher has a public artifact path.

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
| Working local | `builds/zeekr_v12_margined.apk` / `builds/zeekr_v12_os7_nomargin.apk` | Upload to **draft Release** only — not git |
| OS7+ unpadded | Not in tree as a named artifact yet | Confirm whether `zeekr_no_keepalive_signed.apk` or a separate unpadded build is the OS7+ variant; publish under clear name |
| Install bump | Done on prep | `kYnaviAsset` → Release `zeekr_v12_margined.apk` |

## 3. launcher — zeekr_apk_mod (`main`)

| Item | Reality | Pending |
|------|---------|---------|
| Install path | `XCLauncher3-670-yandex-signed.apk` on `main` (LFS) | Blob exists for collaborators |
| Anonymous CDN | **HTTP 404** — repo is **private** (QA T1 FAIL @ 264b9f0) | **Blocker for Install green** |
| Older v2–v7 | Present; leave as history | None |
| Fix (pick one) | Public GitHub Release / public artifact host / app auth download | Required before Maxim go on Install |

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
| zeekr_apk_mod | `main` | `72651e1c5f` | `NOTES-for-Maxim-0044.md` |
| zee-power-toys | `0044-publish-prep` | this branch | `docs/publish/0044-notes-for-maxim.md` |

## Maxim correction (prep branches + source-repo Releases)

1. **APKs only in source repos** — never copy Launcher/YNavi into zee-power-toys.
2. Each repo gets a **prep branch** + draft **Release + GH Actions** (disabled until go).
3. Install points at Release assets on those source repos.
4. `zeekr_apk_mod` private LFS 404 → **public Release on zeekr_apk_mod** (or make artifacts public).

### Prep branches (local tips — no push until go)

| Repo | Prep branch | Workflow |
|------|-------------|----------|
| zee-power-toys | `0044-publish-prep` | `.github/workflows/release.yml` (dispatch; app-release APK) |
| ynavi-zee | `0044-publish-prep` | release dual Zeekr APKs |
| zeekr_apk_mod | `0044-publish-prep` | release Launcher v8 |

### Install Release tags (planned)

| Asset | Repo | Tag | Filename |
|-------|------|-----|----------|
| YNavi margined | ynavi-zee | `ynavi-zeekr-v12` | `zeekr_v12_margined.apk` |
| YNavi OS7+ | ynavi-zee | `ynavi-zeekr-v12` | `zeekr_v12_os7_nomargin.apk` |
| Launcher | zeekr_apk_mod | `launcher-670` | `XCLauncher3-670-yandex-signed.apk` |

### Dual YNavi builds
- `build_zeekr.sh` → margined (left=480) DEFAULT
- `build_zeekr_os7.sh` → left=0 OS7+

## Maxim: no builds in .git

Binaries ship via **draft GitHub Releases** only (delete drafts after 0044 exercise).
Prep branches carry workflows/docs; `gh release create --draft` uploads from local `builds/`.

See sibling NOTES on ynavi-zee / zeekr_apk_mod `0044-publish-prep`.

## Draft Releases created (2026-09-20) — delete after exercise

| Repo | Draft page | Assets |
|------|------------|--------|
| ynavi-zee | https://github.com/maxim-saplin/ynavi-zee/releases/tag/untagged-309029f8dd29d2218b97 | `zeekr_v12_margined.apk`, `zeekr_v12_os7_nomargin.apk` |
| zeekr_apk_mod | https://github.com/maxim-saplin/zeekr_apk_mod/releases/tag/SEE-ZEEKR-APK-MOD-DRAFT | `XCLauncher3-670-yandex-signed.apk` |

Draft download URLs (auth may be required; anonymous = 404):

- https://github.com/maxim-saplin/ynavi-zee/releases/download/untagged-309029f8dd29d2218b97/zeekr_v12_margined.apk
- https://github.com/maxim-saplin/ynavi-zee/releases/download/untagged-309029f8dd29d2218b97/zeekr_v12_os7_nomargin.apk
- https://github.com/maxim-saplin/zeekr_apk_mod/releases/download/SEE-ZEEKR-APK-MOD-DRAFT/XCLauncher3-670-yandex-signed.apk

Install `releaseTag` targets `ynavi-zeekr-v12` / `launcher-670` — resolve after undraft/publish.
