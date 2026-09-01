---
id: "0002"
title: "Verify and publish the signed 0.4 release"
type: FEATURE
status: completed
related_adr: ["0001"]
related_tasks: ["0001", "0003"]
tags: ["release", "macos", "priority-high"]
links:
  - "https://github.com/jakiesluchawki/SZLAUCH/releases/tag/v0.4.0"
  - "https://github.com/jakiesluchawki/SZLAUCH/actions/runs/33489093891"
  - "https://developer.apple.com/forums/thread/776036"
history:
  - date: "2026-09-01"
    status: completed
    who: mieszko
    note: "Closed CI follow-up: verified the public SPKI fingerprint against the supplied DER certificate and allowed only that exact value. Full 11-commit history scan is clean; a synthetic API-key control is still detected. No app or DMG changes."
  - date: "2026-09-01"
    status: completed
    who: mieszko
    note: "Published signed/notarized 0.4.0 as Latest. All 14 unchanged suites passed locally, from the final DMG and from its public download. Installed on the host with settings/history preserved. No app-source changes; native/physical-machine coverage deferred to backlog 0003."
  - date: "2026-09-01"
    status: active
    who: mieszko
    note: "Owner explicitly approved the Daily Brief Apple API key for Szlauch. Notary authentication passed; Xcode cloud Developer ID export returned Apple's known API-key limitation. Prepared an encrypted local key and public CSR for issuance through the owner portal from the manager."
  - date: "2026-09-01"
    status: active
    who: mieszko
    note: "External dependency, not another task: signing keychain was locked. Draft 0.4.0 created; all 14 suites re-passed on the local DMG. No unsigned installer published."
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

Published Szlauch 0.4.0 as the latest public release with the redesigned panel,
licensed Romie/Roobert fonts and all changes from task 0001. The universal app
and DMG are Developer ID signed, notarized and verified after public download.

## Status: Completed

**Current state:** Public release and installed host application are 0.4.0.
Physical Intel/older-macOS coverage and native interactive acceptance remain
explicitly deferred to [0003](../../backlog/0003_FEATURE_native-cross-mac-acceptance.md).

## Context

The original Developer ID keychain was locked, and the owner was using a
remote manager without access to host Keychain Access. The owner explicitly
authorized the existing Daily Brief Apple API key for Szlauch signing and
notarization only, then issued a matching G2 certificate from the prepared CSR.
No existing certificate was revoked and no unrelated application's credentials
or configuration were changed.

## Implementation

- Verified the supplied certificate, CSR and encrypted private key share one
  public key; checked Apple trust, certificate type, team and validity.
- Imported the identity into a dedicated owner-only release keychain with
  codesign-specific access, then built the optimized universal app and DMG.
- Submitted the signed DMG to Apple, inspected the accepted log and stapled it.
- Ran the complete release checks, inspected remounted Finder metadata,
  reviewed fixture layouts and verified the installed application's state.
- Replaced the draft's temporary CSR with the final DMG, published as Latest
  and repeated release tests against an unauthenticated public download.

## Acceptance Criteria

- [x] Signed universal app and DMG use the intended Developer ID.
- [x] Apple notarization, stapled ticket and Gatekeeper checks pass.
- [x] All 14 suites pass for the app mounted from the final signed image.
- [x] Eight fixture layouts render and native popover geometry is recorded.
- [ ] Native controls, actual glass, scrolling and accessibility appearance
  preferences (deferred to 0003; capture/AX permissions unavailable).
- [x] Installer PNG, native background bookmark and icon placement survive
  detach/reopen; bookmark resolves inside the remounted image.
- [ ] Pixel-level Finder confirmation on another Mac (deferred to 0003).
- [x] Installed custom settings and existing traffic history survive the update.
- [x] Designated requirement matches the previous official 0.3.13 release.
- [ ] Existing OS permission grants are exercised after upgrade
  (deferred to 0003; the local pre-update copy was ad-hoc signed).
- [x] Actual architecture, OS and connection-control coverage is recorded.
- [ ] Physical Intel/older-macOS and live Wi-Fi/VPN/sleep acceptance
  (deferred to 0003; no Rosetta runtime and no disruptive host changes).
- [x] Only the verified DMG is public; GitHub marks 0.4.0 as Latest.
- [x] Public download matches the final SHA-256 and passes release checks.
- [x] Secret scanning passes with only the verified public certificate digest
  excepted; a synthetic credential control still triggers the detector.

## Implementation Notes

- Application source: `7c9efbc4182745ff1190e98d68233cc15008be1b`.
  Later commits only record release work. No app source changed in this task.
- Artifact: `Szlauch-0.4.0.dmg`, 2,358,568 bytes.
- Final stapled SHA-256:
  `c15360240ad446c5a489966691e12d9a25da6e81cf90eddae9316ddb7c94aa26`.
- Developer ID Application, team `78N6WG8P57`, G2 intermediary.
  The new identity expires on 2031-09-02.
- Notary submission `23b2848d-3260-48db-b14c-1a2634f0b221`:
  `Accepted`, `issues: []`. App and DMG assessment both report
  `source=Notarized Developer ID`.
- Published at 2026-09-01 10:11:59 UTC, with the exact application commit above.
  The public CSR asset was removed before publication.
- Installed `/Applications/Szlauch.app` from the verified mounted DMG.
  Backups, private preference snapshots, notarization reports and fixture
  renders remain in ignored `.local/release-verification/0.4.0/`.
- Licensed fonts and all signing inputs remain outside Git. The release
  keychain is locked and the original keychain search list is restored.
- See [verification worklog](worklog/2026-09-01-release.md) for reproducible
  commands, installer metadata and signing pitfalls.

## Issues Encountered

- GitHub's generic API-key detector mistook the documented public SPKI digest
  for a credential. Recomputed it from the supplied DER certificate and added
  only that exact public value to the existing allowlist. Full-history and
  positive-control scans confirmed other credential detection remains active.
- The legacy identity in `login_renamed_1.keychain-db` could not sign:
  `errSecInternalComponent`. It was preserved, not revoked or unlocked.
- Xcode cloud Developer ID export using the approved API key failed with
  HTTP 403 / code 7495. Apple documents the limitation in
  [thread 776036](https://developer.apple.com/forums/thread/776036).
  Working notarization credentials do not imply cloud-signing capability.
- A dedicated keychain supplied only via codesign's `--keychain` was not
  discoverable. Temporarily adding it to the search list resolved this;
  the wrapper restored every original entry afterward.
- The local installed copy was freshly identified as ad-hoc 0.4.0, not the
  older signed app assumed during initial handoff. It was backed up before
  installing the now-notarized build; permission migration was not claimed.
- Native screen capture and Accessibility access were unavailable. Fixture
  snapshots use an opaque renderer and are not native Liquid Glass captures.
- Both an x86_64 system executable and the app failed to launch without
  Rosetta. Cross-compilation is not evidence of an Intel runtime test.

## Design Decisions

### From Plan

1. **Signed distribution contract:** Only publish after Developer ID signing,
   Apple acceptance, stapling and mounted-image tests.
2. **Preserve user state:** Back up the installed app/preferences and verify
   appearance settings and nondecreasing traffic totals after the update.

### Emerged

3. **Remote certificate handoff:** Use a fresh encrypted host-local key and
   owner-issued G2 certificate instead of unlocking the legacy keychain.
4. **Narrow credential use:** Reuse only the explicitly authorized Apple API
   key, only for Szlauch. Never put secrets or licensed font inputs in Git.
5. **Temporary keychain discovery:** Add the release keychain only while
   signing; trust codesign, restore the search list, lock the keychain afterward.
6. **Verify the actual delivery:** Download without GitHub authentication,
   compare the stapled digest and rerun all release checks on that file.
7. **Separate coverage from publication:** Record unavailable native and
   physical-machine checks in 0003, without representing fixture or
   cross-compiled results as tests that did not run.

## Modified Tests

None. All 14 existing suites and strict release checks passed unchanged.
The signed and public-download checks additionally required bundled brand
fonts and notarization; no tests, hooks or security checks were bypassed.

## Future Work

- [0003](../../backlog/0003_FEATURE_native-cross-mac-acceptance.md): native
  interaction, accessibility appearance, permission migration and physical
  cross-Mac acceptance. This task does not schedule or promise an automatic run.
