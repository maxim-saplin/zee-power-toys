# Zeekr / AOSP platform signing

Copy phase0’s keystore here before a T3 build (Flutter’s `*.jks` gitignore
keeps signing material out of this repo):

```bash
cp /path/to/zee_hud_2/phase0-diagnostics/tools/zeekr/androiddebugkey.jks \
   android/tools/zeekr/androiddebugkey.jks
```

- Alias: `platformkey` (set in `android/gradle.properties` as `aospKeyAlias`)
- Store/key pass: `android`
- Enable: `useAospDebugKey=true` (already on `t1-harness`)

Verify after build:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-debug.apk
# expect SHA-256: c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8
```

## 0054 keep-data

Release builds with `useAospDebugKey=true` **fail** if this keystore is missing.
Do not fall back to Flutter debug signing for car APKs (sharedUserId). Never `adb uninstall` to clear SHARED_USER — fix the key and `adb install -r`.
