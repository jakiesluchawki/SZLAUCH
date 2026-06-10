# Lore Directory

Context persistence for stateless Codex sessions.

## Required Skills

Use these skills whenever working with project lore:

| Skill | Use |
|---|---|
| `lore-codex` | General lore work, notes, workflows, and session management |
| `lore-codex-git` | Every git commit that references project work |
| `lore-codex-tasks` | Task creation, status changes, completion, and follow-ups |

Never change task lifecycle state without `lore-codex-tasks`. Never create a
git commit without `lore-codex-git`.

## Session Files

| File | Purpose | Committed |
|---|---|---|
| `0-session/current-user.md` | Current contributor | No |
| `0-session/current-task.md` | Symlink to active task | No |
| `0-session/current-task.json` | Active task metadata | No |
| `0-session/team.yaml` | Team source of truth | Yes |
| `0-session/next-tasks.md` | Generated actionable task list | No |
| `README.md` | Generated lore index | Yes |

Before coding, ensure both current user and current task are set through Lore
MCP tools.

## Structure

```text
lore/
├── 0-session/
├── 1-tasks/
│   ├── backlog/
│   ├── active/
│   ├── blocked/
│   └── archive/
├── 2-adrs/
└── 3-wiki/
```

Task files use `NNNN_TYPE_slug.md`. Research notes use `Q-`, `I-`, `R-`,
`S-`, and `G-` prefixes.
