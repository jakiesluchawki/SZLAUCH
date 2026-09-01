---
id: "0002"
title: "Verify and publish the signed 0.4 release"
type: FEATURE
status: active
related_adr: ["0001"]
related_tasks: ["0001"]
tags: ["release", "macos", "priority-high", "waiting-for-owner"]
links:
  - "https://github.com/jakiesluchawki/SZLAUCH/releases"
history:
  - date: "2026-09-01"
    status: active
    who: mieszko
    note: "External dependency, not another task: owner must unlock the signing keychain in macOS. Draft 0.4.0 created; all 14 suites re-passed on the local DMG. No unsigned installer published."
  - date: "2026-09-01"
    status: active
    who: mieszko
    note: "Owner requested the public update; preparing the verified release and requesting keychain unlock through macOS."
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
- [ ] All 14 suites pass for the app mounted from the final signed image.
- [ ] Native controls, readability and stable popover geometry are reviewed.
- [ ] Installer background and icon placement survive detach/reopen.
- [ ] Installed settings/permissions survive the update.
- [ ] Intel/older-macOS and connection-control verification is recorded.
- [ ] Only the verified distribution artifact is published.

## Implementation Notes

- Pulled main before release preparation; application source remains commit
  `7c9efbc4182745ff1190e98d68233cc15008be1b`. No application code changed.
- Created GitHub draft `v0.4.0`, title `Szlauch 0.4.0`, targeting that exact
  commit. Confirmed `isDraft: true` and an empty asset list. Public Latest
  remains the signed and notarized `v0.3.13`.
- Reused the previously built, verified universal app and local DMG in
  `/private/tmp/szlauch-release-0.4.0`. The original artifacts remain in
  `/Users/mieszkomahboob/Projects/SZLAUCH/.local/design-0.4.0/Szlauch.app`
  and `dist/Szlauch-0.4.0-local.dmg`.
- Re-ran `SZLAUCH_REQUIRE_BRAND_FONTS=1 zsh scripts/test-release.sh` with the
  local DMG. All 14 suites passed both before mounting and from the image;
  font presence, universal architectures, layout files, checksum and exact
  mounted executable comparison passed. The temporary mount was detached.
- This is local/ad-hoc validation only. It does not satisfy the final signed
  image, notarization, native visual or cross-machine acceptance criteria.

## Issues Encountered

- `SecKeychainGetStatus` confirmed the signing keychain remains locked.
  Developer ID identity `ABBEE7E6DD03AA35A6E4D7A0212E5477BB9AA277` exists in
  `~/Library/Keychains/login_renamed_1.keychain-db`; the main login keychain
  contains only an Apple Development identity, which is not a substitute.
- A direct Developer ID signing attempt on a disposable app copy returned
  `errSecInternalComponent`. The original installed app was not touched.
  The copy's previous ad-hoc signature still verifies and the release test
  confirmed its executable matches the original local DMG.
- Opened Keychain Access with the required keychain and asked the owner to
  unlock it in macOS. No password was requested in chat or read from files.
- No notarization request or public release was attempted after signing failed.

## Design Decisions

### From Plan

1. **Keep the signed release contract:** Existing official DMGs are signed
   and notarized; an unsigned replacement would regress installation trust.
2. **Preserve the installed app and source:** Release preparation is isolated
   in a separate worktree and no live network or power settings were changed.

### Emerged

3. **Create a draft without assets:** This prepares the release description
   while preventing testers from downloading an unverified installer. The
   owner can inspect the draft; public users still get the trusted release.
4. **Keep the external wait on this task:** The Lore blocked status requires
   a dependency on another task. This is an owner action, so the task remains
   active with an explicit waiting-for-owner tag and no claimed completion.

## Resume

1. Confirm the owner has unlocked `login_renamed_1` in Keychain Access.
2. Rebuild using Developer ID Application for team `78N6WG8P57`, the explicit
   signing keychain and saved notary profile `SzlauchNotary`. Require local
   Romie/Roobert build inputs; never add font binaries to the source repo.
3. Complete signed-image checks, including `SZLAUCH_REQUIRE_NOTARIZATION=1`,
   and record remaining native/cross-machine coverage honestly.
4. Update the existing draft, do not create a duplicate. Replace its draft
   warning and pending verification text only with checks that actually pass.
5. Upload the verified `Szlauch-0.4.0.dmg`, include its final SHA-256, then
   publish as Latest. Verify the public download and checksum after publishing.
