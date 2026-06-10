# Session Directory

Local session state. All generated session files are ignored by git except
`team.yaml`.

| File | Purpose |
|---|---|
| `current-user.md` | Current contributor |
| `current-task.md` | Symlink to active task |
| `current-task.json` | Active task metadata |
| `team.yaml` | Team source of truth |
| `next-tasks.md` | Generated actionable tasks |

Use `lore_set_user`, `lore_set_task`, `lore_list_users`, and
`lore_show_session` to manage session state.
