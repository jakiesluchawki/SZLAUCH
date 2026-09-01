---
id: "0001"
title: "Preserve the traffic ledger when resetting hotspot statistics"
status: accepted
deciders: [mieszko, codex]
related_tasks: ["0001", "0002"]
related_adrs: []
tags: ["data", "hotspot", "persistence"]
links: []
history:
  - date: "2026-09-01"
    status: accepted
    who: codex
    note: "Implemented under the approved audit fixes; record this autonomous implementation choice explicitly."
---

# ADR 0001: Preserve The Traffic Ledger On Hotspot Reset

## Context

The hotspot dashboard and whole-Mac transfer view share persisted traffic
buckets. Deleting hotspot bytes to reset one widget also changed the computer's
historical totals and broke reconciliation between routes.

## Decision

Keep recorded bucket counts intact. Persist a separate hotspot-display baseline
containing the reset day and that day's cumulative download/upload counts.
The hotspot view hides earlier days and subtracts the baseline only on its day.
New traffic and later days are unaffected. Whole-Mac totals always use the ledger.

Retain recent minute buckets across midnight for rolling windows. Mark compacted
daily buckets explicitly so midnight itself is not mistaken for an aggregate.

## Rationale

A presentation reset must not rewrite measurements shared by other views.
The additive Codable/defaults fields preserve the existing storage format and
allow compaction, restart and repeated resets without a second traffic ledger.

## Alternatives Considered

- Delete hotspot fields in every bucket: rejected because whole-Mac history changes.
- Duplicate all hotspot measurements in another store: rejected because two ledgers
  can diverge and require parallel migrations.
- Reset all categories together: rejected because it exceeds the hotspot action's scope.

## Consequences

- Displayed hotspot-since-reset can differ from the full day's hotspot total in
  the whole-Mac breakdown. The confirmation text explains this distinction.
- Previously deleted measurements cannot be recovered.
- Calendar-day comparison follows the current local calendar; historical timezone
  changes are not reconstructed.
- Regression tests must preserve ledger/category totals, count new data after a
  reset, survive compaction and retain midnight rolling-window samples.
