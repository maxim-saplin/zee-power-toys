# CI release (zee-power-toys)

## Tag convention

- `1.0.0+N` or `v1.0.0+N` where `N` is the Flutter `versionCode` / build number.
- Pushing the tag runs `.github/workflows/release.yml`.
- Or: Actions → **release** → Run workflow (optional `tag` input).

## Required secret

| Name | Value |
|------|--------|
| `AOSP_DEBUG_KEYSTORE_BASE64` | `base64 -w0 android/tools/zeekr/androiddebugkey.jks` (local; file is gitignored) |

Add under GitHub → Settings → Secrets and variables → Actions.

Without the secret, release fails loudly (car APKs must use the AOSP/platform key for `sharedUserId`).

## Asset contract

- Upload name: **`zee-power-toys.apk`** (self-update / Install).
- Signed with AOSP debug / platform key (`useAospDebugKey=true`).

## Push CI

`.github/workflows/ci.yml` on `main` / PRs: analyze + test only (no APK).
