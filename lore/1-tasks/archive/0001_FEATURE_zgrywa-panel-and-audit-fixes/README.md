---
id: "0001"
title: "Zgrywa panel redesign and audit fixes"
type: FEATURE
status: completed
related_adr: ["0001"]
related_tasks: ["0002"]
tags: ["design", "macos", "reliability"]
links: []
history:
  - date: "2026-09-01"
    status: active
    who: mieszko
    note: "User approved the audit fixes and prioritised a stronger design using licensed Romie and Roobert."
  - date: "2026-09-01"
    status: completed
    who: mieszko
    note: "Implemented 0.4.0 redesign and audit fixes. All 14 suites pass for the optimized universal app and the mounted local DMG. Added ADR 0001; signing and native acceptance explicitly deferred to 0002."
---

# Zgrywa Panel Redesign And Audit Fixes

## Summary

Improve the native Szlauch panel with Zgrywa typography, clearer measurements
and focused detail screens. Preserve existing features and correct the
approved data/state bugs with regression coverage.

## Status: Completed

**Current state:** Design and audit fixes implemented and locally verified.
The local DMG is not an official distribution release. Signing and native
interactive acceptance are explicitly deferred to 0002.

## Context

Baseline: main at 80765b2, version 0.3.13. The approved audit identified
hotspot reset data loss, midnight aggregation errors, forecast interval
semantics, hidden process polling, mixed rate units and state-handling gaps.
The user prioritises appearance and authorises Romie/Roobert use.

## Acceptance Criteria

- [x] Romie and Roobert register from bundled fonts with a system fallback.
- [x] The panel retains one fixed size, inline return actions and its existing capabilities.
- [x] Details devote space to primary data; measurements and rankings remain readable.
- [x] Palette cycling, appearance gestures and accessibility preferences remain supported.
- [x] Hotspot resets preserve whole-Mac totals and midnight windows remain consistent.
- [x] Rate units, process polling, weather intervals and missing-data states are corrected.
- [x] Commands, error dismissal and Wi-Fi results have bounded failure handling.
- [x] All 14 existing and new regression suites pass after the final parser checks.
- [x] A current optimized universal app and local DMG are built and verified.
- [ ] Signed distribution and native interactive acceptance (deferred to 0002).

## Implementation Notes

- Version 0.4.0. Romie wordmark/short headings and Roobert UI/measurements;
  fonts register in-process, never install system-wide.
- One 384 x 472 pt surface with a stationary header, a 408 pt scroll viewport,
  inline return actions, quiet separators and 220 ms navigation dissolves.
- Transfer places values above sparklines and has a 132 pt linear chart;
  system details use full-width CPU/Memory tabs, eight rows and thin cores.
- Hotspot history has its own seven-day table. Weather gains larger hourly
  tiles, readable conditions and honest unknown/stale states. Wi-Fi and
  local VPN/sleep actions are retained; utilities remain in the gear menu.
- Kernel NET_RT_IFLIST2 counters are 64-bit and rebased after a reset or
  interface identity change. Physical links are summed without counting VPN twice.
- A separate hotspot reset baseline preserves the raw traffic ledger.
  Minute buckets remain available across midnight for rolling windows.
- SI network units; bounded simultaneous pipe draining; process polling only
  while the process view is visible, without overlapping ps invocations.
- Wi-Fi completion verifies the associated SSID, distinguishes authentication
  failures from other errors and does not reopen a password form for an active network.
- Weather normalizes preceding-hour Open-Meteo and next-hour MET rain intervals,
  rejects non-200 responses, handles nullable observations and respects night icons.
- Sleep authorization uses a literal privileged payload and per-user rules;
  removing a legacy rule preserves other users' entries.
- One shared 14-suite script runs in CI, against the built app and the app
  mounted from the DMG. Snapshot mode does not poll or record transfer.
- Packaging copies licensed local fonts, uses the same title type in the
  installer and accepts an explicit signing keychain. Release checks validate
  architecture, matching version/binary, signatures and DMG resources.

## Design Decisions

### From Plan

1. **Romie and Roobert:** Use the supplied fonts with restrained editorial headings.
2. **Native fixed panel:** Preserve geometry, progressive details and normal macOS controls.
3. **Compact menu bar:** Keep upload above download in the bar and download first in panel views.

### Emerged

4. **Separate worktree:** The old task workspace no longer exists; use the current repository baseline.
5. **Local licensed assets:** Ignore raw commercial font inputs; source-only builds use system fonts.
6. **CPU/Memory tabs:** Full-width process names and values are clearer than two narrow columns.
7. **Independent hotspot baseline:** Reset presentation without rewriting the shared ledger; see ADR 0001.
8. **Authored contrast:** Retain curated palettes and gestures, but keep text/traces readable at low tint intensity.
9. **Quiet updates:** Remove rolling digits and per-sample chart animations, not measurement frequency.
10. **Renderer-only fallbacks:** Fixture screenshots replace unsupported AppKit controls with state icons/text
    and use an opaque surface. They must never be described as native glass captures.
11. **Retain trusted installation:** Do not replace the existing signed app with the local ad-hoc build
    while the Developer ID keychain is locked. Do not publish the local DMG as an official release.
12. **Rooted Lore MCP:** Explicitly select this worktree because the desktop server has another working directory.

## Modified Tests

- Rate formatting now checks decimal MB/s and Mb/s instead of binary divisors.
- Network reset expectations changed from assumed 32-bit rollover to rebaselining;
  added real if_msghdr2-shaped buffers with values above 4 GiB.
- Hotspot reset expectations now require unchanged whole-Mac and category totals;
  added new-traffic, repeated-reset, compaction and midnight checks.
- Weather tests now include interval semantics, nullable JSON, unknown rain and night icons.
- Runtime tests cover snapshots and self-tests, not only preview windows.
- Added font, command-runner and cross-feature regression suites. Existing feature suites remain.

## Issues Encountered

- The inherited workspace path is stale; canonical main was clean and current at 80765b2.
- ImageRenderer does not faithfully capture native AppKit controls or Liquid Glass.
  Reviewed eight fixture layouts and launched a native preview; screenshot capture failed,
  and the accessibility AppleEvent query timed out. Native interaction remains follow-up 0002.
- Codex intermittently failed to start commands with "Too many open files"; later recovered.
- Two extreme menu strings exceeded the compact width by less than one point;
  increased the width by one point and verified the minimum-font width guard.
- Source compilation exposed one over-complex fixture expression and a test assumption
  that WeatherSource was CaseIterable. Both were corrected, not waived.
- The Developer ID keychain is locked. The user was directed to Keychain Access;
  no password was requested in chat and no security setting was bypassed.
- Intel is cross-compiled but not executed; older macOS and disruptive VPN/Wi-Fi/sleep
  operations were not exercised on a colleague's machine.

## Verification Results

- All 14 suites passed on the final optimized app and again inside
  Szlauch-0.4.0-local.dmg; strict font presence was required.
- arm64 and x86_64 slices are present; ad-hoc signatures and the DMG checksum
  verify. The mounted binary matches the built binary.
- Eight layout snapshots rendered at 768 x 944. Native preview launched;
  its live CPU process was observed, but capture/AX automation was unavailable.
- The final disk image contains the native Finder background bookmark,
  backgroundType 2, the PNG, the Applications symlink and 96 pt icons at
  (180, 263) and (540, 263). Finder geometry was reduced to 720 x 458;
  visual confirmation of the reopened window remains part of 0002.
- Lore validates for the three new records individually. Full-directory
  validation misidentifies existing AGENTS.md instructions as task/ADR records;
  those unrelated files were not changed.

## Future Work

- 0002: signed/notarized release, native interaction review and installation acceptance.
