---
id: "0003"
title: "Complete native and cross-Mac acceptance"
type: FEATURE
status: backlog
related_adr: []
related_tasks: ["0002"]
tags: ["macos", "testing", "priority-medium", "effort-medium"]
links:
  - "https://github.com/jakiesluchawki/SZLAUCH/releases/tag/v0.4.0"
history:
  - date: "2026-09-01"
    status: backlog
    who: mieszko
    note: "Spawned from 0002 future work. Signed release and public-download tests passed; native interaction, permission migration and physical Intel/older-macOS checks need an appropriate test environment."
---

# Complete Native And Cross-Mac Acceptance

## Summary

Close the explicitly recorded coverage gaps for the released 0.4 panel and
distribution workflow. Do not treat cross-compilation or opaque fixture
renders as native runtime acceptance.

## Context

[0002](../archive/0002_FEATURE_signed-release-acceptance/README.md) published
a signed/notarized universal DMG with 14 passing suites. The host had neither
Screen Recording nor Accessibility access, no Rosetta runtime, and was using
a live connection that must not be interrupted just for a test.

## Implementation

- Use a user-authorized native session to review the actual popover and Finder.
- Test CPU/Memory, transfer, weather, hotspot and Wi-Fi routes, scrolling,
  passive return, hit targets, fixed geometry and menu-bar anchoring.
- Check the appearance gestures, Reduce Motion and Reduce Transparency.
- Upgrade a previously official signed 0.3.13 installation and verify existing
  data and applicable OS grants; record any required one-time prompts.
- Exercise another user's VPN profile, Wi-Fi selection/active-SSID behavior,
  personal-hotspot switching and sleep authorization/cancel flows with consent.
- Run and record the public DMG on a physical Intel Mac and an older supported
  macOS; record exact hardware, OS, architecture and failures.

## Acceptance Criteria

- [ ] Native glass, controls, scrolling and accessibility appearance reviewed.
- [ ] Header anchoring and fixed panel size remain stable across every route.
- [ ] Finder background and drag-to-Applications installation confirmed visually.
- [ ] Official signed-version upgrade preserves data and appropriate OS grants.
- [ ] Another user's VPN, Wi-Fi/hotspot and sleep flows tested without hard-coded identity.
- [ ] Physical Intel and older supported macOS results recorded honestly.
- [ ] Any discovered regression has a focused reproduction and follow-up fix.
