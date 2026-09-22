---
status: ready-for-agent
labels: [usb]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [UsbAdbScreen]
tier: T3
---

# 0085 — USB mode UI shows Peripheral while actually Host

## Block scope
Car session: app USB screen showed Peripheral while device was Host (Maxim switched Host via zSupport). UI must reflect real USB role.

## Definition of Done
- [ ] Read actual USB role from system (not stale cache)
- [ ] Car or instrumented T2 evidence Host vs Peripheral matches UI
