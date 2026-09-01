---
id: "0002"
title: "Verify and publish the signed 0.4 release"
type: FEATURE
status: backlog
related_adr: ["0001"]
related_tasks: ["0001"]
tags: ["release", "macos", "priority-high"]
links: []
history:
  - date: "2026-09-01"
    status: backlog
    who: mieszko
    note: "Spawned from 0001: release signing needs an unlocked Developer ID keychain; native GUI capture/automation was unavailable."
---

# Verify And Publish The Signed 0.4 Release

## Summary

Finish distribution acceptance for the implemented panel redesign. Keep the
trusted installed app and current public release until the new build passes
Developer ID signing, notarization and native checks.

## Context

Task 0001 builds a universal app and local DMG with the licensed fonts.
The signing identity is in the locked login_renamed_1 keychain. Never request
its password in chat, commit font binaries or publish an ad-hoc artifact as
the official installer.

## Implementation

- Have the owner unlock the keychain in Keychain Access.
- Supply SZLAUCH_SIGN_IDENTITY, SZLAUCH_SIGN_KEYCHAIN and SZLAUCH_NOTARY_PROFILE
  with SZLAUCH_REQUIRE_BRAND_FONTS=1 to scripts/build-dmg.sh.
- Run the shared suite and release checks with SZLAUCH_REQUIRE_NOTARIZATION=1.
- Inspect native glass, all routes, scrolling, menus, tab selection, passive
  return, appearance gestures, Reduce Motion and Reduce Transparency.
- Verify Finder's background reference and drag-and-drop layout when reopening
  the final read-only image. Fixture screenshots do not establish this.
- Replace/relaunch the installed signed app, confirm settings and permissions
  survive, then publish the verified versioned DMG on GitHub Releases.
- Obtain an Intel/older-macOS smoke test and a colleague's VPN/Wi-Fi/sleep check
  without disrupting the owner's active network during automated tests.

## Acceptance Criteria

- [ ] Signed universal app and DMG use the intended Developer ID.
- [ ] Apple notarization, stapled ticket and Gatekeeper checks pass.
- [ ] All 14 suites pass for the app mounted from the final image.
- [ ] Native controls, readability and stable popover geometry are reviewed.
- [ ] Installer background and icon placement survive detach/reopen.
- [ ] Installed settings/permissions survive the update.
- [ ] Intel/older-macOS and connection-control verification is recorded.
- [ ] Only the verified distribution artifact is published.
