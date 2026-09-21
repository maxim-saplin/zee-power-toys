# Zeekr / AOSP platform signing

The AOSP platform debug keystore is **committed** at
`android/tools/zeekr/androiddebugkey.jks` (explicitly un-gitignored) and used for
car / `sharedUserId` builds.

```bash
flutter build apk --release -PuseAospDebugKey=true
```

- Alias: `androiddebugkey` (or `aospKeyAlias` in `android/gradle.properties`)
- Store/key pass: `android` (see `android/gradle.properties`)
- Enable: `-PuseAospDebugKey=true`

Verify after build:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
# expect SHA-256: c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8
```

## 0054 keep-data

Release builds with `useAospDebugKey=true` **fail** if this keystore is missing.
Do not fall back to Flutter debug signing for car APKs (`sharedUserId`). Never
`adb uninstall` to clear SHARED_USER — fix the key and `adb install -r`.
