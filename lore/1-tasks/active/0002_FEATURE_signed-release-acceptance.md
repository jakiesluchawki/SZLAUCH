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
  - "https://developer.apple.com/forums/thread/776036"
history:
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

Finish distribution acceptance for the implemented panel redesign. Keep the
trusted installed app and current public release until the new build passes
Developer ID signing, notarization and native checks.

> Waiting for an Apple-issued Developer ID Application certificate matching
> the prepared public CSR. The owner is using a remote manager and cannot
> interact with Keychain Access on the host.

## Context

Task 0001 builds a universal app and local DMG with the licensed fonts.
The existing signing identity is in a locked legacy keychain. Never request
its password in chat, commit font binaries or publish an ad-hoc artifact as
the official installer. Do not revoke existing certificates.

## Implementation

- Have the Account Holder issue an additional Developer ID Application
  certificate using the prepared CSR in the Apple Developer website.
- Verify its public key, team, certificate type, validity and trust before
  importing it alongside the matching private key in a dedicated keychain.
- Build with SZLAUCH_SIGN_IDENTITY, SZLAUCH_SIGN_KEYCHAIN and the local fonts.
  Notarize with the explicitly authorized Apple API key on the host.
- Run all suites and release checks with SZLAUCH_REQUIRE_NOTARIZATION=1.
- Review native glass, routes, scrolling, controls, stable geometry, appearance
  gestures, Reduce Motion and Reduce Transparency.
- Reopen the read-only DMG and verify Finder's background and drag/drop layout.
- Verify installed settings/permissions and record cross-machine coverage.
- Remove the temporary CSR asset before publishing only the verified installer.

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

- Pulled main; application source remains commit
  `7c9efbc4182745ff1190e98d68233cc15008be1b`. No application code changed.
- GitHub draft `v0.4.0` targets that exact commit. Public Latest remains the
  signed and notarized `v0.3.13`; no 0.4.0 installer has been uploaded.
- Reused the verified universal app and local DMG in
  `/private/tmp/szlauch-release-0.4.0`. Original artifacts are in the canonical
  project's `.local/design-0.4.0/Szlauch.app` and
  `dist/Szlauch-0.4.0-local.dmg`.
- Re-ran `SZLAUCH_REQUIRE_BRAND_FONTS=1 zsh scripts/test-release.sh`.
  All 14 suites passed before mounting and from the local DMG. Fonts,
  architectures, layout files, checksum and exact executable comparison passed.
- This is ad-hoc validation only, not final signed-image acceptance.
- After explicit owner approval, `notarytool history` authenticated with the
  existing Daily Brief API key. No private key content or submission details
  were logged; no credentials were uploaded to GitHub.
- Prepared an RSA-2048 private key encrypted with AES-256-CBC in PKCS#8 form,
  with a random passphrase. Both local files are owner-only inside the ignored
  `.local/signing/szlauch-release-20260901/` directory (0700).
- The CSR signature and matching public key passed verification. A second run
  reused the same key without overwriting it. Public-key SPKI SHA-256:
  `48f16281481e19d90d027375132c90e26d1b6ec8a09c008d2a79108fd7f5abf7`.
- Draft asset `Szlauch-Developer-ID.certSigningRequest` contains only the
  public request, so the owner can download it on the manager. SHA-256:
  `ed81d8a8218e57e393119e3edb5b2a162b9b4f66bca26a93f96386cebb22bc59`.
  It must be removed before the release becomes public.

## Issues Encountered

- Legacy Developer ID identity `ABBEE7E6DD03AA35A6E4D7A0212E5477BB9AA277`
  remains in locked `~/Library/Keychains/login_renamed_1.keychain-db`.
  Direct signing returned `errSecInternalComponent`. Apple Development or
  Apple Distribution certificates are not Developer ID substitutes.
- Xcode 26.6 cloud export with the authorized API key failed with HTTP 403,
  result code 7495, for `DEVELOPER_ID_APPLICATION_MANAGED`.
  Apple DTS documents this exact API-key/cloud Developer ID failure in
  [thread 776036](https://developer.apple.com/forums/thread/776036).
  Notary authentication success does not establish signing permission.
- Temporarily omitted only the locked legacy keychain during the cloud export.
  Its restoration to the original search list was verified after failure.
- No attempts to alter account roles, bypass access checks, use other API keys,
  revoke certificates or weaken Gatekeeper were made.
- Reading existing Apple portal tabs through Safari timed out. No browser
  session credentials were extracted and no private browser data was read.
- No 0.4.0 notarization submission or public publication has occurred.
  The installed signed app and other applications remain unchanged.

## Design Decisions

### From Plan

1. **Keep the signed release contract:** Official downloads require Developer ID
   signing and notarization, not the local ad-hoc installer.
2. **Isolate release work:** Preserve the installed app, source and live network.

### Emerged

3. **Prepare a draft:** Keep the description ready without exposing an
   unverified installer. The temporary public CSR is an owner-only draft asset.
4. **Use a fresh local identity:** Apple account-owner certificate issuance can
   be done from the manager, without unlocking the legacy host keychain.
5. **Keep the external wait explicit:** Lore requires another task for a blocked
   status. Keep active with waiting-for-owner; do not invent a dependency.
6. **Limit credential reuse:** The owner approved only the Daily Brief API key
   for Szlauch signing/notarization. The approval does not authorize other keys
   or unrelated account/application changes.

## Resume

1. Obtain the `.cer` issued by the Account Holder from the prepared CSR.
   Verify it matches the recorded SPKI, Developer ID Application and team
   `78N6WG8P57`; do not regenerate the key or revoke the legacy certificate.
2. Import into a dedicated local signing keychain, rebuild with the licensed
   Romie/Roobert inputs, sign both app and DMG, then notarize using the approved
   key via `notarytool --key --key-id --issuer`. Keep all secrets on the host.
3. Complete signed-image checks, including SZLAUCH_REQUIRE_NOTARIZATION=1.
   Record remaining native/cross-machine coverage honestly.
4. Update the existing draft and remove the CSR asset. Replace pending checks
   only with results that actually passed. No duplicate draft or unsigned DMG.
5. Upload `Szlauch-0.4.0.dmg` with its final SHA-256, publish as Latest,
   then verify the downloaded artifact and checksum.
