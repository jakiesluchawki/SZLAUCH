# Lore Index

> Auto-generated on 2026-11-19 22:09. Do not edit manually.
> Use `lore_generate-index` tool to regenerate.

Quick reference for task dependencies, status, and ADR relationships.

## Quick Stats

| Active | Blocked | Backlog | Completed | ADRs |
|:------:|:-------:|:-------:|:---------:|:----:|
| 0 | 1 | 1 | 2 | 1 |

## Ready to Start

These tasks have no blockers (or all blockers completed):

- **Task 0004**: [Show the local date and improve dashboard flow](lore/1-tasks/blocked/0004_FEATURE_date-and-dashboard-flow.md) — blocks 0 tasks (low)

## Dependency Graph

```mermaid
flowchart LR
    subgraph Completed
        T0001["0001: Zgrywa panel redesign and..."]
        T0002["0002: Verify and publish the si..."]
    end
    subgraph Blocked
        T0004["0004: Show the local date and i..."]
    end
    subgraph Backlog
        T0003["0003: Complete native and cross..."]
    end
    subgraph ADRs
        ADR0001[/"ADR 0001: Preserve the traffic..."/]
    end


    ADR0001 -.-> T0001
    ADR0001 -.-> T0002
```

## Task Status

| ID | Title | Type | Status | Blocked By | Blocks | ADRs |
|:---|:------|:-----|:-------|:-----------|:-------|:-----|
| 0004 | [Show the local date and improve das...](lore/1-tasks/blocked/0004_FEATURE_date-and-dashboard-flow.md) | FEATURE | blocked | — | — | — |
| 0003 | [Complete native and cross-Mac accep...](lore/1-tasks/backlog/0003_FEATURE_native-cross-mac-acceptance.md) | FEATURE | backlog | — | — | — |
| 0001 | [Zgrywa panel redesign and audit fix...](lore/1-tasks/archive/0001_FEATURE_zgrywa-panel-and-audit-fixes/README.md) | FEATURE | completed | — | — | 0001 |
| 0002 | [Verify and publish the signed 0.4 r...](lore/1-tasks/archive/0002_FEATURE_signed-release-acceptance/README.md) | FEATURE | completed | — | — | 0001 |

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
