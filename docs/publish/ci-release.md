# CI release (zee-power-toys)

## Tag convention

- `1.0.0+N` or `v1.0.0+N` where `N` is the Flutter `versionCode` / build number.
- Pushing the tag runs `.github/workflows/release.yml`.
- Or: Actions → **release** → Run workflow (optional `tag` input).

## Signing

Uses the **committed** AOSP debug keystore at `android/tools/zeekr/androiddebugkey.jks`
(explicitly tracked; same public platform debug key used for car `sharedUserId` installs).
**No GitHub Actions secret required.**

Build: `flutter build apk --release -PuseAospDebugKey=true`.

## Asset contract

- Upload name: **`zee-power-toys.apk`** (self-update / Install).
- Signed with AOSP debug / platform key (`useAospDebugKey=true`).

## Push CI

`.github/workflows/ci.yml` on `main` / PRs: analyze + test only (no APK).
