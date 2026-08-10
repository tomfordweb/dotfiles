---
name: clean-worktrees
description: Sweep this repo's worktrees — remove the ones fully merged to main, report the ones holding incomplete or unpushed work. USE WHEN the user invokes /clean-worktrees, asks to "prune worktrees", "clean up worktrees", or after an MR-merging session leaves stale worktrees behind.
---

# clean-worktrees — one pass, remove merged, surface stranded work

Scope: THIS repo's worktrees only (`workmux ls`). Efficiency matters — classify every
worktree with cheap git plumbing in one sweep, no per-worktree exploration, no builds.

## Classify (one pass)

`git fetch origin` once, then for each worktree (path from `workmux ls`):

1. **Dirty?** `git -C <wt> status --porcelain` non-empty → has uncommitted work.
2. **Unpushed?** `git -C <wt> rev-list --count @{u}..HEAD` > 0 (or no upstream at all
   with local commits: `git rev-list --count origin/main..HEAD` > 0).
3. **Merged?** `git merge-base --is-ancestor <branch> origin/main` → plainly merged.
   Not an ancestor but clean: check the forge for a merged MR on that branch
   (`glab mr list --state merged --source-branch <branch>` / gh equivalent) — catches
   squash/rebase merges that ancestry can't see.

Cheap checks first (dirty/unpushed are pure-local); only clean candidates hit the forge.

## Act

- **Merged + clean + nothing unpushed** → remove. Print the removal list + count first
  (batch-op rule), then `workmux rm <name>` each (removes worktree, window/session, and
  branch).
- **Everything else is NEVER removed.** Report it instead.
- Finish with `workmux claude prune` (drops stale ~/.claude.json entries for the
  worktrees just deleted).

## Report

One table, no prose per row:

`worktree | branch | verdict (removed / merged-but-dirty / unpushed commits / uncommitted changes / active-unmerged / no-MR) | detail`

For stranded-work rows add the one thing needed next: "3 unpushed commits on X",
"dirty: 2 files", "MR !123 open". If a worktree looks abandoned (dirty + no MR + no
recent commits), suggest rescue options (commit + MR, or explicit user OK to discard) —
do not decide discard yourself.

## Guardrails

- Never `workmux rm` anything dirty, unpushed, or ambiguous — removal deletes the
  branch. When unsure, report.
- No pushes, no MR creation in this flow — it's a sweep, not a landing. Hand rescue
  work to `/rebase-mrs` or `/ship`.
- Beads: if a removed worktree's branch had a linked issue still open, note it in the
  report (probably needs closing or re-scoping).
