---
status: ready-for-agent
labels: [ynavi, stretch, port]
created: 2026-09-21
satisfies: Port Zee customs onto YNavi 30.8.1; Releases-only packaging for Maxim manual test
tier: T2
owner: zee-dev
blocked-by: [0076, 0071]
modules: [ynavi-zee build, apktool, SpeedCam / Phase0 bridges]
priority: stretch-after-primary
filed-by: zee-pdm
---

# 0078 — STRETCH: YNavi 30.8.1 disassemble + port + Releases-only

## Why
Maxim overnight stretch: when 0071–0077 primary empties, port mods from v27-era onto **30.8.1**.

## Input
`ynavi-zee/tmp/ru.yandex.yandexnavi_30.8.1-739652660_2arch_1dpi_afa9a6ca147d27ae2e85dee765dca7ab_apkmirror.com.apkm`

## Scope
- Disassemble same pipeline as v27
- Port **all** current custom changes; rebuild signed variants as today
- T2 smoke (emu-5554; no N1)
- **Packaging:** new YNavi Release(s) with v30 mod **only listed under Releases** — **do not** reference/link from toys app UI or README install paths Maxim uses day-to-day (manual test only)

## DoD
- [ ] Primary 0076+0071 (and Artemis 0077) not starved
- [ ] Build Success or honest HARD BLOCK + why
- [ ] T2 smoke FINDINGS if built
- [ ] Releases-only; no in-app deep link to v30
- [ ] PDM sign-off
