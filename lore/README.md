# Lore Index

> Auto-generated on 2026-09-01 11:14. Do not edit manually.
> Use `lore_generate-index` tool to regenerate.

Quick reference for task dependencies, status, and ADR relationships.

## Quick Stats

| Active | Blocked | Backlog | Completed | ADRs |
|:------:|:-------:|:-------:|:---------:|:----:|
| 1 | 0 | 0 | 1 | 1 |

## Ready to Start

These tasks have no blockers (or all blockers completed):

- **Task 0002**: [Verify and publish the signed 0.4 release](lore/1-tasks/active/0002_FEATURE_signed-release-acceptance.md) — blocks 0 tasks (low)

## Dependency Graph

```mermaid
flowchart LR
    subgraph Completed
        T0001["0001: Zgrywa panel redesign and..."]
    end
    subgraph Active
        T0002["0002: Verify and publish the si..."]
    end
    subgraph ADRs
        ADR0001[/"ADR 0001: Preserve the traffic..."/]
    end


    ADR0001 -.-> T0002
    ADR0001 -.-> T0001
```

## Task Status

| ID | Title | Type | Status | Blocked By | Blocks | ADRs |
|:---|:------|:-----|:-------|:-----------|:-------|:-----|
| 0002 | [Verify and publish the signed 0.4 r...](lore/1-tasks/active/0002_FEATURE_signed-release-acceptance.md) | FEATURE | **active** | — | — | 0001 |
| 0001 | [Zgrywa panel redesign and audit fix...](lore/1-tasks/archive/0001_FEATURE_zgrywa-panel-and-audit-fixes/README.md) | FEATURE | completed | — | — | 0001 |

## Architecture Decision Records

| ID | Title | Status | Related Tasks |
|:---|:------|:-------|:--------------|
| 0001 | [Preserve the traffic ledger when resetting hotspot statistics](lore/2-adrs/0001_preserve-traffic-ledger-on-hotspot-reset.md) | accepted | 0001, 0002 |

## Legend

**Task Status:**
- `active` — Work can proceed
- `blocked` — Waiting on dependencies
- `backlog` — Planned but not yet started
- `completed` — Done, in archive

**Graph Arrows:**
- `A --> B` — A blocks B (B depends on A)
- `ADR -.-> Task` — ADR informs Task
