---
name: ship
description: Commit, push, and open a merge request when user explicitly asks to ship work.
user-invocable: true
---

# Ship

Review changes, run required repository validation, commit scoped files, push the working branch, and open a merge request when user requests shipping.

Do not create, update, or link GitLab issues. Do not add `Closes #` text, milestones, or labels unless user explicitly requests them.

Never push directly to the default branch.

## Beads trailer

In a repo with a `.beads/` directory, every commit that resolves a tracked issue ends with a trailer naming it:

```
fix(app): gate booking status to Pro

Beads: romi-pq32.4
```

One id per commit, on its own line, after a blank line. Several ids go on several `Beads:` lines rather than a comma list.

The trailer is how a deploy pipeline can close the issue when the code actually reaches production, so write it even when you also close the issue by hand. A `bd close` says the work is finished, the trailer says which release carried it. A repo whose pipeline reads these will warn on a branch that has none, and will never close anything for a deploy that failed.

Never invent an id. If the work has no issue, either file one first or ship without the trailer.
